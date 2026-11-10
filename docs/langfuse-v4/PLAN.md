# Fresh Langfuse v4 implementation plan

## Confirmed scope

Focused compatibility work for fresh v4 deployments. Existing v3 data migration is a separate future phase. Preserve Oracle IDCS, the `/langfuse` public path, managed OCI Postgres/Valkey, OCI Object Storage, Vault secret references, and the current OCI GenAI gateway integration.

This plan proposes implementation work; it does not change deployed infrastructure. Do not use the current live v3 stack as the first upgrade test.

## Phase 1: Pin the release contract

- [x] Record the authentication dependency and redirect behavior in ASSESSMENT.md.
- [ ] Pin a chart/application pair; initial candidate is chart 2.2.4 with its default application 4.77.0, rather than implicitly selecting latest 4.78.0.
- [ ] Confirm the pinned application's auth dependency matches the inspected 4.78.0 behavior.
- [ ] Resolve the application tag once from the selected chart and use it consistently for builds, OCIR publication and deployment. Fail if resolution is empty or inconsistent.

Verify: build and rendered web/worker image references use the exact same application version; Helm artifact uses the chart version.

## Phase 2: Preserve application behavior

- [ ] Retain the custom web build for both IDCS redirects and build-time `/langfuse` support. Validate patch applicability against the resolved package.
- [ ] Keep worker and OCI gateway build behavior initially; evaluate prebuilt images separately after the v4 deployment works.
- [ ] Remove duplicate generated environment names through typed chart settings and shared environment configuration, while preserving effective values.
- [ ] Preserve IDCS claims, callback URL, account linking and password/signup behavior.
- [ ] Preserve the Postgres TLS URL, certificate paths, Secret references and CSI mounts.
- [ ] Explicitly configure Redis authentication semantics and TLS; avoid inheriting a new username from chart defaults.
- [ ] Preserve S3-compatible endpoint, bucket, region, path-style access and credentials.

Verify: rendered manifests match the configuration mapping in ASSESSMENT.md, with no unintended secret rotation or changed auth behavior.

## Phase 3: Provision chart v2 prerequisites

- [ ] Install a pinned ClickHouse operator after cert-manager is ready.
- [ ] Wait for required CRDs and operator/webhook readiness before deploying the application chart.
- [ ] Replace obsolete ZooKeeper/Bitnami settings with explicit ClickHouse/Keeper replica, resource, storage-class and capacity settings.
- [ ] Choose and set a consistent fresh-install v4 write mode on web and worker; avoid implicitly reusing this policy for an existing-data upgrade.
- [ ] Update Terraform/schema defaults and descriptions for the agreed v4 deployment track. Retain upstream safeguards against upgrading a v1 release onto empty v2 storage.

Verify: ordering is explicit in the deployment graph; a missing/unready operator fails with actionable diagnostics.

## Phase 4: Validate before merge

- [ ] Run Terraform formatting/validation and pinned Helm lint/render checks with non-sensitive fixture values.
- [ ] Test OIDC redirect behavior, failed responses and token POST semantics without exposing credentials.
- [ ] Deploy a fresh isolated OKE stack; verify OL8/OL9 node bootstrap and private-image pulls.
- [ ] Complete real IDCS login/logout and returning-user/account-linking tests in a browser. Request user login when required.
- [ ] Verify database migrations/TLS, Redis queues/TLS, ClickHouse processing and OCI Object Storage upload/read/export/delete operations.
- [ ] Verify trace ingestion/query, evaluator calls through the existing OCI gateway, health paths, ingress/TLS and HPA.
- [ ] Verify registry credential refresh, reboot and node replacement.
- [ ] Commit implementation and follow the repository merge workflow after end-to-end validation. Record unverified gates explicitly.

Acceptance: a fresh v4 deployment preserves the existing IDCS and OCI service workflows and passes the relevant end-to-end checks. Existing v3 stack migration and stock-image adoption are not acceptance requirements for this first pass.
