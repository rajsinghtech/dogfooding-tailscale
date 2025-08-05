# google-gke-autopilot

Google Kubernetes Engine (GKE) Autopilot cluster deployment.

## Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `project_id` | string | The Google Cloud Project ID | `tailscale-sandbox` |
| `region` | string | The region for the GKE cluster | `us-central1` |
| `zone` | string | The zone for the GKE cluster | `us-central1-a` |
| `authorized_networks` | map(string) | Map of CIDR blocks and their display names for master authorized networks | - |
| `cluster_name` | string | The name of the GKE cluster | `gke-autopilot-cluster` |
| `tenant` | string | The tenant name for the cluster | `sales` |
| `environment` | string | The environment name for the cluster | `sandbox` |
| `stage` | string | The stage name for the cluster | `test` |
| `oauth_client_id` | string | The OAuth client ID for the cluster | - |
| `oauth_client_secret` | string | The OAuth client secret for the cluster | - |
| `tags` | map(string) | A map of tags to add to all resources | - |
