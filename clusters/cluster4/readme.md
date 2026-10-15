# Cluster 4

Terraform (`*-k8s-setup`) installs Flux Operator, the `FluxInstance` and the
bootstrap Secrets; Flux then reconciles `clusters/cluster4/flux`.

```sh
make -C clusters/cluster4 check
make -C clusters/cluster4 reconcile
make -C clusters/cluster4 render
```

To bootstrap without Terraform:

```sh
CLIENT_ID=... CLIENT_SECRET=... make -C clusters/cluster4 bootstrap SOPS_GPG_KEY_FILE=/secure/path/private-key.asc
```
