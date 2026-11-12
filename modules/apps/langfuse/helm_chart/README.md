# Langfuse Chart Module

This module manages the deployment and configuration of the Langfuse application using the Langfuse Helm chart. 
It provisions the necessary Kubernetes resources and integrates with OCI DevOps for deployment of the Langfuse chart.
Some of the steps (image build and secrets creation) are performed in a compute instance builder VM as DevOps requires PAT tokens to access public github repos which makes the 1-click deployment process more complex for the end user.


## Secret creation across chart versions

Chart 1.x and the assessed chart 2.x use the same application Secret names and
keys in this stack: `langfuse` (salt, encryption key, NextAuth secret and
ClickHouse password), `langfuse-idcs`, `langfuse-postgres`,
`langfuse-postgres-cert`, and `langfuse-s3`. Keep
`scripts/create_oke_secrets.sh` shared while that contract is unchanged.
The Redis password key it also creates remains unchanged; matching the managed
Redis service's authentication settings belongs in the chart values.

Chart environment-variable and datastore-topology changes are separate from
Secret creation. If a future chart version changes the Secret contract, select
its creation script at artifact publication as the image-build module does,
keeping the existing DevOps artifact entry point stable.

## Chart prerequisites

The existing pre-Helm shell stage also runs
`scripts/install_langfuse_prerequisites.sh` with the selected chart version:

- Chart 1.x skips the ClickHouse operator setup.
- Chart 2.x waits for the OKE cert-manager deployments in `cert-manager`,
  installs ClickHouse operator Helm chart `0.0.8` in `clickhouse-operator`, and
  waits for the ClickHouse/Keeper CRDs and operator deployment to be ready.

The application Helm deployment already depends on this shell stage. Keep
`clickhouse.crdCheck` enabled during real installation; disabling it only
hides the missing prerequisite. The v2 dependency stage has a 20-minute limit
for secrets, certificates and operator initialization.

Run `python3 tests/langfuse_chart/test_prerequisites.py` to test selection,
ordering and failure propagation with mocked cluster/Helm commands.

The chart values qualify ClickHouse/Keeper repositories with `docker.io` because
OKE's container runtime can reject short names as ambiguous. Verify compatibility
with downloaded, pinned chart archives:

```sh
python3 tests/langfuse_chart/check_values_render.py /path/to/langfuse-1.5.41.tgz /path/to/langfuse-2.2.4.tgz
```

This checks that the new values leave v1 container images unchanged and produce
fully qualified v2 ClickHouse/Keeper references.
