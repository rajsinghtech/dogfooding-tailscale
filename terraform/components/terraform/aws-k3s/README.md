# AWS K3s with Tailscale Integration

This Terraform component creates a single-node K3s cluster on AWS with Tailscale integration. It deploys:

1. A new VPC with public and private subnets
2. An EC2 instance running K3s
3. Tailscale installed and configured on the instance
4. An example Nginx application deployed on the K3s cluster

## Prerequisites

- AWS account and credentials
- Tailscale account and OAuth client credentials
- SSH key pair in AWS

## Usage

```hcl
module "k3s" {
  source = "terraform/components/terraform/aws-k3s"

  # Basic Information
  tenant      = "myuser"
  environment = "dev"
  stage       = "test"
  name        = "tailscale-k3s"
  region      = "us-west-2"
  
  # AWS configuration
  vpc_cidr     = "10.0.0.0/16"
  ssh_keyname  = "my-aws-key"
  instance_type = "t3.medium"
  
  # Tailscale configuration
  instance_hostname    = "k3s-demo"
  oauth_client_id      = var.oauth_client_id
  oauth_client_secret  = var.oauth_client_secret
  advertise_routes     = ["10.0.0.0/16"]
  
  tags = {
    Owner       = "DevOps"
    Environment = "Development"
  }
}
```

## Example Deployment

This component automatically deploys a sample Nginx application to demonstrate K3s functionality. The application consists of:

1. A namespace called `demo`
2. A deployment with 2 replicas of Nginx
3. A ClusterIP service exposing the Nginx deployment

## Accessing the Cluster

There are two ways to access the deployed resources:

### Via SSH (Public IP)

```bash
ssh -i your-key.pem ubuntu@<instance_public_ip>
```

### Via Tailscale

Once the instance is authorized in your Tailscale admin console:

```bash
ssh ubuntu@<tailscale_hostname>
```

### Accessing Kubernetes

On the instance, the kubeconfig is located at `/etc/rancher/k3s/k3s.yaml`. To access it remotely, you can copy it to your local machine:

```bash
ssh -i your-key.pem ubuntu@<instance_public_ip> 'sudo cat /etc/rancher/k3s/k3s.yaml' > kubeconfig.yaml
```

You will need to update the server address in the kubeconfig to use either the instance's public IP or Tailscale hostname.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| tenant | Name of the user/tenant for the Atmos Stack | `string` | n/a | yes |
| environment | Short-form name of the region for the Atmos Stack | `string` | n/a | yes |
| stage | Name of stage | `string` | n/a | yes |
| name | Name of the K3s cluster | `string` | n/a | yes |
| region | AWS Region for the K3s VM | `string` | n/a | yes |
| ssh_keyname | AWS SSH Keypair Name | `string` | n/a | yes |
| vpc_cidr | AWS VPC CIDR | `string` | `"10.0.0.0/16"` | no |
| instance_type | EC2 instance type for the K3s node | `string` | `"t3.medium"` | no |
| root_volume_size | Size of the root volume in GB | `number` | `20` | no |
| oauth_client_id | The OAuth application's ID | `string` | n/a | yes |
| oauth_client_secret | The OAuth application's secret | `string` | n/a | yes |
| instance_hostname | Tailscale Machine hostname of the EC2 instance | `string` | n/a | yes |
| advertise_routes | List of CIDR blocks to advertise via Tailscale | `list(string)` | `[]` | no |
| tailscale_tags | List of Tailscale tags to apply to the instance | `list(string)` | `["tag:k3s"]` | no |
| tags | Map of tags to assign to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | ID of the EC2 instance |
| instance_public_ip | Public IP address of the EC2 instance |
| instance_private_ip | Private IP address of the EC2 instance |
| vpc_id | ID of the VPC |
| vpc_cidr | CIDR block of the VPC |
| tailscale_hostname | Tailscale hostname of the instance |
| k3s_kubeconfig_command | Command to get kubeconfig from the instance |
| tailscale_access_instructions | Instructions for accessing the K3s instance via Tailscale |
| demo_app_access_instructions | Instructions for accessing the demo application | 