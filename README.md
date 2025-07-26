# Dogfooding Tailscale

An opinionated Terraform + ArgoCD GitOps playground for experimenting with Tailscale on Kubernetes across multiple cloud providers/on-prem.

> **Note**: This repository is for learning and experimentation only. No support is provided. PRs are welcome in good faith and if germane but no guarentees are made that they will be committed. Use at your own risk. Here be dragons.

## Built With

* [Terraform](https://www.terraform.io/) - Infrastructure as Code
* [Atmos](https://atmos.tools/) - Terraform orchestration
* [Tailscale](https://tailscale.com/) - Mesh networking
* [ArgoCD](https://argo-cd.readthedocs.io/) - GitOps deployment
* AWS EKS, Azure AKS, Google GKE - Kubernetes platforms

## Getting Started

### Prerequisites

* Tailscale account
* Cloud provider accounts (AWS, Azure, and/or GCP)
* Terraform >= 1.5.0
* Atmos CLI (optional if you want to use it to orchestrate Terraform)
* kubectl and cloud CLIs
* Docker (for local Kind clusters)

### Installation

1. Clone the repository

   ```sh
   git clone https://github.com/rajsinghtech/dogfooding-tailscale.git
   cd dogfooding-tailscale
   ```

2. Follow along with READMEs in the individual root modules under `terraform/components/terraform/`

3. If using Atmos, configure and customize the user variables using the example files in `terraform/stacks/catalog` , `terraform/stacks/deploy` and `terraform/stacks/workflows` otherwise just use the example `.tfvars` files in each root module for plain ol' Terraform.

## Project Structure

```sh
.
├── clusters/                   # Kubernetes manifests and ArgoCD configs
│   ├── cluster0-kind/         # Local Kind cluster
│   ├── cluster1-3/            # Cloud clusters
│   └── templates/             # Reusable templates
├── terraform/                  # Infrastructure code
│   ├── components/terraform/   # Root modules
│   │   ├── aws-*/             # AWS components
│   │   ├── azure-*/           # Azure components
│   │   ├── google-*/          # GCP components
│   │   └── modules/           # Shared modules
│   └── stacks/                # Atmos configurations
└── docs/                      # Additional docs
```

## Available Components

### AWS

* `aws-eks` - EKS cluster with VPC and Tailscale
* `aws-k8s-setup` - Kubernetes configurations and apps
* `aws-k3s` - Lightweight K3s option

### Azure

* `azure-aks` - AKS cluster setup
* `azure-k8s-setup` - Azure Kubernetes configs
* `azure-ts-perf-testing` - Performance testing setup

### Google Cloud

* `google-gke-autopilot` - GKE Autopilot cluster
* `google-gke-dpv2` - GKE with Dataplane V2

## Resources

* [Tailscale Kubernetes Docs](https://tailscale.com/kb/1185/kubernetes)
* [Atmos Documentation](https://atmos.tools/)

## License

MIT
