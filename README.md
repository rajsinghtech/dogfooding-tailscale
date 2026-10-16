# Dogfooding Tailscale

An opinionated Terraform + Flux GitOps playground for experimenting with Tailscale on Kubernetes across multiple cloud providers and local Kind.

> **Note**: This repository is for learning and experimentation only. No support is provided. PRs are welcome in good faith and if germane but no guarentees are made that they will be committed. Use at your own risk. Here be dragons.

## Built With

* [Terraform](https://www.terraform.io/) - Infrastructure as Code
* [Atmos](https://atmos.tools/) - Terraform orchestration
* [Tailscale](https://tailscale.com/) - Mesh networking
* [Flux](https://fluxcd.io/) - GitOps deployment
* AWS EKS, Azure AKS, Google GKE - Kubernetes platforms

## Getting Started

### Prerequisites

* Tailscale account and an OAuth client for the Kubernetes operator (see [terraform/README.md](terraform/README.md))
* Cloud provider accounts (AWS, Azure, and/or GCP), or Docker for local Kind
* Terraform >= 1.9.0 (CI uses 1.16.x) and the Atmos CLI
* kubectl, Helm, the Flux CLI and SOPS
* The private PGP key for `clusters/.sops.yaml` (never committed; passed at bootstrap time)

### Installation

1. Clone the repository

   ```sh
   git clone https://github.com/rajsinghtech/dogfooding-tailscale.git
   cd dogfooding-tailscale
   ```

2. Follow along with READMEs in the individual root modules under `terraform/components/terraform/`

3. If using Atmos, copy and customize the example files in `terraform/stacks/catalog`, `terraform/stacks/deploy`, and `terraform/stacks/workflows`.

## How the clusters are wired

1. Terraform creates the cloud cluster (`aws-eks`, `azure-aks`, `google-gke-dpv2`).
2. The matching `*-k8s-setup` root installs cloud add-ons, CoreDNS split-DNS rewriting and, through
   `modules/flux-bootstrap`, the [Flux Operator](https://fluxoperator.dev/), a `FluxInstance`, and the
   `sops-gpg` and `tailscale/operator-oauth` Secrets.
3. Flux syncs `clusters/<cluster>/flux` and installs everything else from `clusters/common/apps`: the
   Tailscale operator, Connector and ProxyClass, kube-prometheus-stack with Tailscale dashboards, demo
   apps, and the GitHub webhook receiver. Cluster-specific apps live in `clusters/<cluster>/apps`.

| Cluster | Platform | Terraform roots |
|---------|----------|-----------------|
| `cluster0-kind` | Local Kind | none (`make -C clusters/cluster0-kind init`) |
| `cluster1` | Azure AKS | `azure-aks`, `azure-k8s-setup` |
| `cluster2` | AWS EKS (+ PeerRelay) | `aws-eks`, `aws-k8s-setup` |
| `cluster3` | AWS EKS | `aws-eks`, `aws-k8s-setup` |
| `cluster4` | GKE Dataplane V2 | `google-gke-dpv2`, `google-k8s-setup` |

Per-cluster values (names, Connector CIDR, operator hostname, optional image tags) are in
`clusters/<cluster>/flux/vars/cluster-settings.yaml`; secrets are SOPS-encrypted in `cluster-secrets.sops.yaml`.
Flux and Flux Operator versions are pinned in `clusters/common/bootstrap/versions.env`.

## Testing without cloud credentials

```sh
make kwok-test CLUSTER=cluster2               # bootstrap through the Terraform flux-bootstrap module
make kwok-test CLUSTER=cluster0-kind KWOK_BOOTSTRAP=make
make atmos-validate                           # Atmos stacks + every workflow's validate-all
make dns-test                                 # split-DNS CoreDNS rewrite used on GKE
```

`test/kwok/run.sh` starts a [KWOK](https://kwok.sigs.k8s.io/) control plane (real kube-apiserver, etcd,
scheduler and controller-manager, simulated nodes and pods) and runs Flux Operator and the Flux controllers as
host processes, so it needs no Docker, root or cloud access. It syncs a snapshot of the working tree, swaps the
SOPS key for a throwaway one, and asserts that every Kustomization and HelmRelease becomes Ready. Pods do not
really run, so the Tailscale data plane is not exercised. CI runs it for every cluster
(`.github/workflows/kwok-flux.yaml`).

## Project Structure

```sh
.
├── clusters/
│   ├── common/
│   │   ├── apps/              # Flux Kustomizations shared by every cluster
│   │   ├── bootstrap/         # FluxInstance template, versions.env, cluster.mk
│   │   └── flux/              # Shared HelmRepositories
│   └── cluster*/              # Per-cluster Flux entrypoint, vars and apps
├── terraform/
│   ├── components/terraform/  # Root modules and shared modules
│   └── stacks/                # Atmos catalog, deploy and workflow examples
├── test/
│   ├── kwok/                  # KWOK + Flux end-to-end harness
│   └── atmos/                 # Atmos validation
└── docs/                      # Additional docs (peer relay metrics, IPv6 routing notes)
```

## Available Components

### AWS

* `aws-eks` - EKS cluster with VPC and Tailscale
* `aws-k8s-setup` - EKS add-ons and the Flux bootstrap
* `aws-k3s` - Lightweight K3s option

### Azure

* `azure-aks` - AKS cluster setup
* `azure-k8s-setup` - AKS CoreDNS/split-DNS and the Flux bootstrap
* `azure-ts-perf-testing` - Performance testing setup

### Google Cloud

* `google-gke-autopilot` - GKE Autopilot cluster
* `google-gke-dpv2` - GKE with Dataplane V2
* `google-k8s-setup` - Kubernetes configs for the Dataplane V2 cluster

## Resources

* [Tailscale Kubernetes Docs](https://tailscale.com/kb/1185/kubernetes)
* [Flux Documentation](https://fluxcd.io/flux/)
* [Atmos Documentation](https://atmos.tools/)

## License

MIT
