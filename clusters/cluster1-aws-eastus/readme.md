# Builds yamls

- `kustomize build clusters/templates/argo-cd --enable-helm | kubectl apply -f -`  
- `kubectl apply -f clusters/cluster1-aws-eastus/argocd/applications.yaml`  

# Init cluster

- `cd terraform/aws-eks/`   
- `terraform init`  
- `terraform plan --var-file=../../clusters/cluster1-aws-eastus/terraform.tfvars`
- `terraform apply --auto-approve --var-file=../../clusters/cluster1-aws-eastus/terraform.tfvars`
