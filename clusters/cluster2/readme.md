# Cluster 2

Terraform (`*-k8s-setup`) installs Flux Operator, the `FluxInstance` and the
bootstrap Secrets; Flux then reconciles `clusters/cluster2/flux`.

```sh
make -C clusters/cluster2 check
make -C clusters/cluster2 reconcile
make -C clusters/cluster2 render
```

To bootstrap without Terraform:

```sh
CLIENT_ID=... CLIENT_SECRET=... make -C clusters/cluster2 bootstrap SOPS_GPG_KEY_FILE=/secure/path/private-key.asc
```
