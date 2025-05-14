# GKE Autopilot Cluster Terraform Configuration

This Terraform configuration creates a Google Kubernetes Engine (GKE) Autopilot cluster with the following features:

- Autopilot enabled (managed nodes)
- Public endpoint access
- IP whitelisting for kube-apiserver access
- Network Policy enabled
- Shielded Nodes enabled
- Cloud Run and Cloud Build integration
- Cloud Logging and Monitoring enabled
- GKE Dataplane V2 enabled

## Requirements

- Terraform >= 0.13
- Google Cloud Provider plugin
- Google Cloud credentials configured

## Variables

The following variables can be configured:

- `project_id`: Google Cloud Project ID (**Required user variable**)
- `region`: Region for the cluster (default: us-central1)
- `zone`: Zone for the cluster (default: us-central1-a)
- `oauth_client_id`: Tailscale OAuth client ID for the cluster to properly install the Tailscale K8s Operator Helm chart (**Required user variable**)
- `oauth_client_secret`: Tailscale OAuth client secret for the cluster properly install the Tailscale K8s Operator Helm chart (**Required user variable**)
- `cluster_name`: Name of the GKE cluster (default: autopilot-cluster)
- `machine_type`: Node machine type (default: e2-medium)
- `min_nodes`: Minimum number of nodes (default: 1)
- `max_nodes`: Maximum number of nodes (default: 3)
- `tenant`: Tenant name for the cluster (default: sales)
- `environment`: Environment name for the cluster (default: sandbox)
- `stage`: Stage name for the cluster (default: test)
- `authorized_networks`: Map of CIDR blocks (your machine's public IP/s for example) and their display names for allowed networks/ACL to the kubeapiserver (**Required variable for access**)

## Usage

1. Set up your Google Cloud credentials
2. Initialize Terraform:
   ```bash
   terraform init
   ```
3. Setup vars in a .tfvars file or as command line variables below
4. Plan the deployment:
   ```bash
   terraform plan -var="project_id=your-project-id" -var="oauth_client_id=your-oauth-client-id" -var="oauth_client_secret=your-oauth-client-secret" -var="authorized_networks={\"your-ip-address/32\": \"your-ip-address\"}"
   ```
5. Apply the configuration:
   ```bash
   terraform apply -var="project_id=your-project-id" -var="oauth_client_id=your-oauth-client-id" -var="oauth_client_secret=your-oauth-client-secret" -var="authorized_networks={\"your-ip-address/32\": \"your-ip-address\"}"
   ```

6. Get the kubeconfig:
   The `terraform apply` output will show you the exact command to get the kubeconfig. It will look like:
   ```bash
   gcloud container clusters get-credentials <cluster-name> --region <region>
   ```
   After running this command, you can use `kubectl` to interact with your cluster.

## Notes

- The cluster for now is using public controlplane/APIserver and uses a custom VPC network and subnet
- The cluster is configured with autoscaling
- The configuration includes timeouts for long-running operations
