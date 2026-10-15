# Cluster0 (Kind)

Local Kind cluster using the same Flux tree as the cloud clusters.

```sh
CLIENT_ID=... CLIENT_SECRET=... make -C clusters/cluster0-kind init SOPS_GPG_KEY_FILE=/secure/path/private-key.asc
make -C clusters/cluster0-kind check
make -C clusters/cluster0-kind delete
```

For CI-style validation without Docker or credentials, use the KWOK harness:
`make kwok-test CLUSTER=cluster0-kind` from the repository root.
