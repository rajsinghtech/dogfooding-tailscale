SHELL := /bin/bash

CLUSTER ?= cluster2
CLUSTERS := cluster0-kind cluster1 cluster2 cluster3 cluster4
KWOK_BOOTSTRAP ?= terraform

.PHONY: kwok-test kwok-test-all atmos-validate dns-test render tailscale-provider-pr825

# End-to-end Flux reconciliation of one cluster on KWOK (no Docker or cloud credentials).
kwok-test:
	KWOK_BOOTSTRAP=$(KWOK_BOOTSTRAP) test/kwok/run.sh $(CLUSTER)

kwok-test-all:
	for c in $(CLUSTERS); do KWOK_BOOTSTRAP=$(KWOK_BOOTSTRAP) test/kwok/run.sh $$c || exit 1; done

atmos-validate:
	test/atmos/validate.sh

# Functional test of the split-DNS CoreDNS config used on GKE.
dns-test:
	test/dns/split-dns.sh

render:
	for c in $(CLUSTERS); do $(MAKE) -s -C clusters/$$c render >/dev/null && echo "rendered $$c"; done

# tailscale_tailnet is unreleased (tailscale/terraform-provider-tailscale#825). Builds the PR
# head into terraform/work and writes the CLI config the tailnet component points
# TF_CLI_CONFIG_FILE at. Drop once the PR ships in a release.
TS_PROVIDER_PR825_SHA := 0e7f7303f317bdb70d703d4300601efe0a05f9dc
TS_PROVIDER_DIR := $(abspath terraform/work/providers/tailscale-pr825)

tailscale-provider-pr825:
	rm -rf $(TS_PROVIDER_DIR) && mkdir -p $(TS_PROVIDER_DIR)
	git -C $(TS_PROVIDER_DIR) init -q src
	git -C $(TS_PROVIDER_DIR)/src fetch -q --depth 1 https://github.com/tailscale/terraform-provider-tailscale $(TS_PROVIDER_PR825_SHA)
	git -C $(TS_PROVIDER_DIR)/src checkout -q FETCH_HEAD
	cd $(TS_PROVIDER_DIR)/src && GOTOOLCHAIN=auto go build -o $(TS_PROVIDER_DIR)/terraform-provider-tailscale .
	rm -rf $(TS_PROVIDER_DIR)/src
	printf 'provider_installation {\n  dev_overrides {\n    "tailscale/tailscale" = "%s"\n  }\n  direct {}\n}\n' $(TS_PROVIDER_DIR) > $(abspath terraform/work/tailscale-pr825.tfrc)
