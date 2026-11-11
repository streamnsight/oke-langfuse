# Native OCI Object Storage with OKE workload identity

Investigated 2026-11-11. Branch: `feature/oci-object-storage-workload-identity`,
based independently on `feature/langfuse-v4`.

## Release contract and decision

The pinned application 4.77.0 already includes `OCIObjectStorageService` and
the OCI TypeScript SDK. Its auth switch explicitly builds an OKE workload
identity provider. No custom storage patch or new application dependency is
needed. Verified that the chart-1.5.41 application, 3.224.1, also has this auth
switch; arbitrary older v3 releases have not been verified.

Instance principal and workload identity are different supported auth modes.
Use workload identity here to restrict access to the Langfuse service account,
namespace and cluster instead of granting storage access to all node workloads.
Enhanced OKE is required; the cluster data-source guard now enforces this for
managed as well as existing clusters. A basic cluster must be upgraded before
using this configuration. There is no automatic fallback to instance principal.

Both web and worker receive:

```text
LANGFUSE_USE_OCI_NATIVE_OBJECT_STORAGE=true
LANGFUSE_OCI_AUTH_TYPE=workload_identity
```

They use the chart-created `langfuse` service account in namespace `langfuse`,
with token automount enabled. The chart still routes bucket, region and endpoint
through `LANGFUSE_S3_*` variables: these names are also used by the native OCI
client. The endpoint changes from the namespace-prefixed S3 compatibility API
to `https://objectstorage.${REGION}.oraclecloud.com`. OCI discovers the namespace
using `getNamespace({})`. Chart 2.2.4 has no `oci` storageProvider enum; leave
that field as `s3` and select OCI with the explicit environment flag.

The bucket name and existing per-purpose object paths are preserved. Event
uploads, media uploads and batch exports all inherit the native endpoint.
No S3 access-key or secret-key environment variables are rendered. Credential
Vault entries, Kubernetes secret creation and CSI secret references are removed.
Deprecated root Terraform credential inputs remain nullable and hidden in the
Resource Manager schema so existing tfvars remain accepted; they are unused.
The chart module no longer accepts credential inputs.

## IAM and rollout behavior

A deployment-specific IAM policy grants `manage objects` only in the bucket's
compartment, constrained by bucket name and the exact workload identity.
This covers reads, lists, multipart uploads, writes and retention deletes.
A second statement grants `manage buckets` constrained to `PAR_MANAGE` and the
same bucket/identity. The native client generates pre-authenticated requests
for signed media upload/download and export URLs, so object permissions alone
are insufficient. It cannot create, delete or reconfigure buckets. There are
no tenancy-wide storage grants or node-instance storage grants.

The chart module depends on policy creation. IAM propagation and pod token
exchange still require live verification. Do not rotate API keys or revoke
existing customer secrets until the native flows pass. Existing S3 Kubernetes
secrets may remain on an upgraded cluster, but are no longer read; remove them
after validation. Applying Terraform removes the two Terraform-managed Vault
secrets from desired state, so review that plan and preserve an appropriate
rollback path before applying. This branch has not been applied.

The application creates object-scoped, expiring pre-authenticated URLs. Treat
these as bearer URLs; test browser/SDK access and CORS with the actual caller
origins. Expired PAR records may need operational cleanup; OCI blocks bucket
deletion while PAR records remain. This feature does not implement PAR cleanup.

## Future ClickHouse form factor / cold storage

This work configures Langfuse application blob access. ClickHouse's MergeTree
object-storage disks run inside the ClickHouse server and use a separate client
and authentication configuration; they do not inherit Langfuse's OCI SDK or
web/worker service account. A future offload feature must establish supported
ClickHouse-to-OCI authentication before promising a fully keyless solution.

Keep ClickHouse cold parts in a dedicated bucket (and separate IAM identity),
not intermingled with Langfuse's event/media/export blobs. Define hot/cold TTLs,
cache sizing, operator storage configuration, retention, backup/restore and
failure behavior separately. Preserve existing application prefixes for upgrades.
Do not add an OCI Archive-tier lifecycle rule to active ClickHouse parts or
Langfuse blobs: archived objects need restoration before reads. Current bucket
auto-tiering to InfrequentAccess remains unchanged. No cold-storage behavior or
future bucket permissions are enabled here.

## Plan and verification

### Phase 1 — research and implementation

- [x] Verify native provider and auth modes in pinned application source.
- [x] Configure shared web/worker environment, account and regional endpoint.
- [x] Add exact-identity, bucket-scoped object and PAR IAM permissions.
- [x] Remove required S3 input/provisioning and stale CSI references.
- [x] Preserve object paths and document the future ClickHouse storage boundary.

### Phase 2 — offline validation

- [x] Terraform init without backend and root `terraform validate` pass.
- [x] Changed Terraform formatting, shell syntax and diff whitespace pass.
- [x] Render charts 1.5.41 / 2.2.4: assert web and worker account, exactly one
  native flag/auth mode, three native endpoints and no credential env/Secret refs.
- [x] Run secret provisioning with mocked OCI/Kubernetes CLIs and assert it
  requests no S3 keys while still provisioning the remaining application secrets.

Commands:

```sh
terraform init -backend=false -input=false
terraform validate
python3 tests/langfuse_chart/check_values_render.py chart-1.5.41.tgz chart-2.2.4.tgz
python3 -m unittest discover -s tests/langfuse_chart -p 'test_*.py'
```

### Phase 3 — isolated OKE validation (pending; required before merge)

- [ ] Review Terraform plan, IAM scope and Vault-secret removal/rollback path.
- [ ] Deploy to the fresh v4 enhanced cluster through the stack pipeline.
- [ ] Verify both pods' service account and successful OCI token exchange.
- [ ] Ingest/query a unique trace; verify worker event fetch and object persistence.
- [ ] Upload/read media through real SDK/browser PAR URLs; verify CORS.
- [ ] Export/download a batch; list/read/delete disposable test objects.
- [ ] Verify another service account cannot access the bucket, and Langfuse cannot
  access another bucket or change bucket configuration.
- [ ] Restart web/worker and verify token refresh without user credentials.
- [ ] Record results and follow repository review/merge workflow.

## Primary sources

- [Pinned native client and auth switch](https://github.com/langfuse/langfuse/blob/v4.77.0/packages/shared/src/server/services/StorageService.ts)
- [Pinned environment schema](https://github.com/langfuse/langfuse/blob/v4.77.0/packages/shared/src/env.ts)
- [Pinned chart routing helpers](https://github.com/langfuse/langfuse-k8s/blob/langfuse-2.2.4/charts/langfuse/templates/_helpers.tpl)
- [OKE workload identity and enhanced-cluster requirement](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contenggrantingworkloadaccesstoresources.htm)
- [Object/PAR permissions](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/objectstoragepolicyreference.htm)
- [PAR behavior and required permissions](https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/usingpreauthenticatedrequests.htm)
