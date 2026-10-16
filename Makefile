SHELL := /bin/bash

CLUSTER ?= cluster2
CLUSTERS := cluster0-kind cluster1 cluster2 cluster3 cluster4
KWOK_BOOTSTRAP ?= terraform

.PHONY: kwok-test kwok-test-all atmos-validate dns-test render

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
