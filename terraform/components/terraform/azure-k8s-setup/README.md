# azure-k8s-setup

Kubernetes setup for Azure AKS clusters with Tailscale operator deployment.

## Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `tenant` | string | Name of the user/tenant for the Atmos Stack | - |
| `environment` | string | Short-form name of the region for the Atmos Stack | - |
| `stage` | string | Name of stage | - |
| `location` | string | Azure region for deployment | - |
| `proxy_replicas` | string | Number of replicas for Tailscale ProxyGroup pods | - |
| `tailscale_operator_image_tag` | string | Image tag for the Tailscale operator (`stable`, `unstable`, or specific version) | `stable` |
| `tailscale_proxy_image_tag` | string | Image tag for the Tailscale proxy (`stable`, `unstable`, or specific version) | `stable` |