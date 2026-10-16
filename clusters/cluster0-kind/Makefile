CLUSTER := cluster0-kind
KIND ?= kind

include ../common/bootstrap/cluster.mk

.PHONY: init delete

# Requires Docker, CLIENT_ID/CLIENT_SECRET (Tailscale OAuth client) and SOPS_GPG_KEY_FILE.
init:
	$(KIND) create cluster --name $(CLUSTER) --config kind-config.yaml
	$(MAKE) bootstrap

delete:
	$(KIND) delete cluster --name $(CLUSTER)
