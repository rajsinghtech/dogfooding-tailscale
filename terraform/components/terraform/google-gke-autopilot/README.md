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

- `project_id`: Google Cloud Project ID
- `region`: Region for the cluster (default: us-central1)
- `zone`: Zone for the cluster (default: us-central1-a)
- `allowed_ip`: IP address to allow access to kube-apiserver
- `cluster_name`: Name of the GKE cluster (default: autopilot-cluster)
- `machine_type`: Node machine type (default: e2-medium)
- `min_nodes`: Minimum number of nodes (default: 1)
- `max_nodes`: Maximum number of nodes (default: 3)

## Usage

1. Set up your Google Cloud credentials
2. Initialize Terraform:
   ```bash
   terraform init
   ```
3. Plan the deployment:
   ```bash
   terraform plan -var="project_id=your-project-id" -var="allowed_ip=your-ip-address"
   ```
4. Apply the configuration:
   ```bash
   terraform apply -var="project_id=your-project-id" -var="allowed_ip=your-ip-address"
   ```

5. Get the kubeconfig:
   The `terraform apply` output will show you the exact command to get the kubeconfig. It will look like:
   ```bash
   gcloud container clusters get-credentials <cluster-name> --region <region>
   ```
   After running this command, you can use `kubectl` to interact with your cluster.

## Security Features

- IP whitelisting for kube-apiserver access
- Network Policy enabled
- Binary Authorization enabled
- Workload Identity enabled

## Notes

- The cluster uses a custom VPC network and subnet
- The cluster is configured with autoscaling
- The configuration includes timeouts for long-running operations
