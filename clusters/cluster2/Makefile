# Bootstrap Flux config - run AFTER Terraform installs operators
# Applies sops-gpg secret and tells Flux what repo to watch
bootstrap:
	kubectl apply -k ../common/bootstrap/flux
	kubectl apply -f flux/config/cluster.yaml

# Check Flux status
check:
	flux check

# Get all Flux resources
status:
	flux get all -A

# Reconcile Flux
reconcile:
	flux reconcile source git dogfooding-tailscale
	flux reconcile kustomization cluster

# Suspend Flux reconciliation
suspend:
	flux suspend kustomization --all

# Resume Flux reconciliation
resume:
	flux resume kustomization --all
