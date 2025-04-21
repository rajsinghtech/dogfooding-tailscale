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

## TODO

- Add CSI provisioners and load-balancer controllers for AWS - **Done**
- Add CSI provisioner for Azure  
- Azure not tested yet! Run at your own risk. AWS code has been tested and works atm  
