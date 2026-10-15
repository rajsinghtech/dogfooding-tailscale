# azure-k8s-setup

Phase 2 for an `azure-aks` cluster: CoreDNS split-DNS rewriting, the Tailscale split-DNS nameserver, and
the Flux bootstrap (`modules/flux-bootstrap`). Flux then installs the Tailscale operator and all workloads
from `flux_cluster_path`.

## Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `tenant` | string | Name of the user/tenant for the Atmos Stack | - |
| `environment` | string | Short-form name of the region for the Atmos Stack | - |
| `stage` | string | Name of stage | - |
| `flux_cluster_path` | string | Cluster directory Flux syncs, e.g. `clusters/cluster1/flux` | - |
| `sops_gpg_private_key_file` | string | Path to the private PGP key for `clusters/.sops.yaml` | - |
| `flux_git_url` | string | Git repository Flux syncs | `https://github.com/rajsinghtech/dogfooding-tailscale` |
| `flux_git_ref` | string | Git reference Flux syncs | `refs/heads/main` |
