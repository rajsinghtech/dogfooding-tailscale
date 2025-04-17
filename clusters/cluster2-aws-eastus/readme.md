# Builds yamls
kustomize build clusters/templates/argo-cd --enable-helm | kubectl apply -f -
kubectl apply -f clusters/cluster1-aws-eastus/argocd/applications.yaml