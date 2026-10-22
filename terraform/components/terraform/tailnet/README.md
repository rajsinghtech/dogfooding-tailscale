# tailnet

Creates a throwaway [API-only tailnet](https://tailscale.com/docs/features/tailnet-creation-api) named
`<tenant>-<environment>-<stage>`. Its OAuth client (scope `all`) is exported for the next phase and kept in state, because
deleting the tailnet needs it. `terraform destroy` deletes the tailnet.

`tailscale_tailnet` is unreleased ([terraform-provider-tailscale#825](https://github.com/tailscale/terraform-provider-tailscale/pull/825)).
Run `make tailscale-provider-pr825` from the repository root and set `TF_CLI_CONFIG_FILE` to `terraform/work/tailscale-pr825.tfrc`
(`stacks/catalog/kind.yaml.example` does this). Remove both once the PR ships in a release.

Inputs: an OAuth client with the `tailnets` scope in the creating tailnet.
