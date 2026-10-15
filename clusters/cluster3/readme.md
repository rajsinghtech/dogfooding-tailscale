# Cluster 3

Terraform (`*-k8s-setup`) installs Flux Operator, the `FluxInstance` and the
bootstrap Secrets; Flux then reconciles `clusters/cluster3/flux`.

```sh
make -C clusters/cluster3 check
make -C clusters/cluster3 reconcile
make -C clusters/cluster3 render
```

To bootstrap without Terraform:

```sh
CLIENT_ID=... CLIENT_SECRET=... make -C clusters/cluster3 bootstrap SOPS_GPG_KEY_FILE=/secure/path/private-key.asc
```
