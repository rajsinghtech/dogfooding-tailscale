# Shared targets for clusters/<name>/Makefile. Each cluster Makefile sets CLUSTER
# and includes this file. Cloud clusters are bootstrapped by Terraform
# (*-k8s-setup); `make bootstrap` is the equivalent for any other cluster.
SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../../..)
include $(ROOT)/clusters/common/bootstrap/versions.env

KUBECTL ?= kubectl
FLUX ?= flux
HELM ?= helm
GIT_URL ?= https://github.com/rajsinghtech/dogfooding-tailscale
GIT_REF ?= refs/heads/main
CLUSTER_PATH ?= clusters/$(CLUSTER)/flux
SOPS_GPG_KEY_FILE ?=

.PHONY: bootstrap flux-operator secrets flux-instance check status reconcile suspend resume render

bootstrap: flux-operator secrets flux-instance

flux-operator:
	$(HELM) upgrade --install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
		--version $(FLUX_OPERATOR_VERSION) --namespace flux-system --create-namespace --wait

secrets:
	@test -n "$(SOPS_GPG_KEY_FILE)" || { echo "Set SOPS_GPG_KEY_FILE to the private PGP key for clusters/.sops.yaml"; exit 1; }
	@test -n "$${CLIENT_ID:-}" && test -n "$${CLIENT_SECRET:-}" || { echo "Set CLIENT_ID and CLIENT_SECRET to a Tailscale OAuth client for the operator"; exit 1; }
	$(KUBECTL) create namespace flux-system --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(KUBECTL) create secret generic sops-gpg --namespace flux-system \
		--from-file=sops.asc="$(SOPS_GPG_KEY_FILE)" --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(KUBECTL) create namespace tailscale --dry-run=client -o yaml | $(KUBECTL) apply -f -
	@$(KUBECTL) create secret generic operator-oauth --namespace tailscale \
		--from-literal=client_id="$$CLIENT_ID" --from-literal=client_secret="$$CLIENT_SECRET" \
		--dry-run=client -o yaml | $(KUBECTL) apply -f -

flux-instance:
	FLUX_VERSION=$(FLUX_VERSION) GIT_URL=$(GIT_URL) GIT_REF=$(GIT_REF) CLUSTER_PATH=$(CLUSTER_PATH) \
		$(FLUX) envsubst --strict < $(ROOT)/clusters/common/bootstrap/flux-instance.yaml | $(KUBECTL) apply -f -
	$(KUBECTL) -n flux-system wait fluxinstance/flux --for=condition=Ready --timeout=10m

check:
	$(FLUX) check
	$(KUBECTL) -n flux-system get fluxinstance flux
	$(FLUX) get kustomizations -A

status:
	$(KUBECTL) get pods -A
	$(FLUX) get all -A

reconcile:
	$(FLUX) reconcile kustomization dogfooding-tailscale -n flux-system --with-source

suspend:
	$(FLUX) suspend kustomization --all -n flux-system

resume:
	$(FLUX) resume kustomization --all -n flux-system

render:
	kustomize build $(ROOT)/$(CLUSTER_PATH)
	kustomize build $(ROOT)/$(CLUSTER_PATH)/vars
