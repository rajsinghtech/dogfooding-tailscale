# Setup Instructions

## Tailscale Admin UI Steps

- Make sure you have at minimum the following tags created: `tag:subnet-router` and `tag:k8s-operator` in your ACL file setup with proper ownership hierarchy
- Create a set of Oauth credentials from the Admin UI with the following scopes at minimum by checking the following boxes:
  - The ```Write``` box for ```DNS```
  - The ```Write``` box for ```Core``` under the ```Devices``` section, then click on ```Add tags``` and select ```tag:k8s-operator``` and `tag:subnet-router`  
  - The ```Write``` box for ```Routes```
  - The ```Write``` box for ```Auth Keys``` under the ```Keys``` section, then make sure the ```tag:k8s-operator``` and `tag:subnet-router` have been added again
- Turn on Autoapprovers for the subnet routes in the ACL file if desired - how to know what they are:
  - Both AWS and Azure stacks will create 3 private IPv4 subnets with `+4` added to the netmask and `0,16,32` for the 3rd octet based off the VPC CIDR you set. As an example, let's say you set the `vpc_cidr` variable to `10.0.0.0/16` then the subnets that get generated will be `10.0.0.0/20`, `10.0.16.0/20` and `10.0.32.0/20`

- Peer relays (`tailscale_peer_relay_port` on the subnet routers, and the `PeerRelay` resource in
  `clusters/cluster2/apps/peer-relay`) also need a grant with the `tailscale.com/cap/relay` capability in your policy file

## Flux bootstrap inputs

Each `*-k8s-setup` root bootstraps Flux with `modules/flux-bootstrap` and needs:

- `flux_cluster_path`: the cluster directory Flux syncs, e.g. `clusters/cluster2/flux`
- `sops_gpg_private_key_file`: path to the private PGP key for `clusters/.sops.yaml`. Terraform stores it
  in the `flux-system/sops-gpg` Secret, so it also ends up in Terraform state: keep state local and private.
- `flux_git_url` / `flux_git_ref` (optional): the repository and ref to sync

The Tailscale OAuth client from phase 1 becomes the `tailscale/operator-oauth` Secret used by the
Flux-managed operator.

## Atmos Steps

We're using [Atmos](https://atmos.tools/faq/) to spin up multiple Terraform stacks so we can try to stay as [DRY](https://spacelift.io/blog/terraform-dynamic-blocks) as possible.

- [Install Atmos](https://atmos.tools/install)
- Use the AWS or Azure example files under `stacks/catalog`, `stacks/deploy` and `stacks/workflows` to get your configs together as necessary
- As an example:
  - Copy `stacks/catalog/aws-eks.yaml.example` to `stacks/catalog/aws-eks.yaml` and input your vars
  - Copy `stacks/deploy/tenant-aws-environment-stage.yaml.example` file to a meaningful YAML named file as a template to create as many of your own stacks per region
  - Copy `stacks/workflows/aws-eks-workflow.yaml.example` to `stacks/workflows/ts-eks-workflow.yaml` and make any modifications as needed to the workflows for your stacks
  - Use the `atmos` wrapper+workflow commands to deploy the stacks at once. Note that running `plan-all` will make the second root module for `aws-k8s-setup` (plan-phase2) barf out because there is no tfstate yet as apply hasn't been run for the stack when starting fresh to pull variables and cluster auth from (as the cluster doesn't exist yet), so just run the plan for the first phase and make sure there's no errors.
    - `atmos workflow validate-all -f aws-eks-workflow`
    - `atmos workflow plan-phase1 -f aws-eks-workflow`
    - `atmos workflow apply-all -f aws-eks-workflow`
  - To destroy everything once testing is done:
    - `atmos workflow destroy-all -f aws-eks-workflow`
- The other workflows are `azure-aks-workflow`, `gke-dpv2-workflow` (GKE Dataplane V2 + `google-k8s-setup`)
  and `gce-gke-workflow` (GKE Autopilot, single phase)

## Kind on a throwaway tailnet

The `kind-workflow` stack runs the `cluster0-kind` Flux tree on a new API-only tailnet that the stack creates and destroys.

1. Create an OAuth client with the `tailnets` scope in an existing tailnet. It goes in `oauth_client_id`/`oauth_client_secret` for the `tailnet` component.
2. `make tailscale-provider-pr825` from the repository root. `tailscale_tailnet` is only in
   [terraform-provider-tailscale#825](https://github.com/tailscale/terraform-provider-tailscale/pull/825), so this builds it into
   `terraform/work/`. The `tailnet` component points `TF_CLI_CONFIG_FILE` at it. Needs Go.
3. Copy `stacks/catalog/kind.yaml.example`, `stacks/deploy/tenant-kind-environment-stage.yaml.example` and
   `stacks/workflows/kind-workflow.yaml.example` without the `.example` suffix, then fill in the OAuth client and the SOPS key path.
4. `atmos workflow apply-all -f kind-workflow`, which runs `tailnet` → `kind` → `kind-k8s-setup`.
5. `atmos workflow destroy-all -f kind-workflow` removes the cluster and deletes the tailnet.

`kind` sets up what the operator needs in the new tailnet before Flux installs it: HTTPS certificates, `tag:k8s-operator`/`tag:k8s`
tag owners, a Tailscale Services auto-approver for `tag:k8s`, and the operator OAuth client (`auth_keys`, `devices:core`, `services`).

## TODO

- Add CSI provisioner for Azure
