# Langfuse v4 compatibility assessment

Assessment date: 2026-11-10. Branch: `feature/langfuse-v4`.

This is an assessment and proposed migration direction, not an implementation or authorization to upgrade a running stack. The branch lives in a separate worktree because the original checkout has an in-progress merge.

## Findings and recommendation

Keep the custom web-image build for the first v4 implementation. The latest inspected Langfuse release still needs our redirect accommodation, and the existing `/langfuse` URL path independently requires a build-time setting. Avoid changing authentication, public URLs, application major version, and storage topology simultaneously.

The version snapshot is:

| Component | Inspected version | Meaning |
| --- | --- | --- |
| Latest published application release | `v4.78.0` | Authentication assessment target |
| Latest chart listed in the upstream index | `2.2.4` | Downloaded package verified against its Chart.yaml |
| Chart 2.2.4 default application | `4.77.0` | Chart and application versions are independent; do not silently substitute 4.78.0 |
| Authentication wrapper in v4.78.0 | `next-auth` 4.24.15 | Resolved lockfile version; upstream also patches it |
| Transitive OpenID library | `openid-client` 5.7.1 | Still the v5 implementation, not v6 |

Sources: [application releases](https://github.com/langfuse/langfuse/releases), [pinned lockfile](https://github.com/langfuse/langfuse/blob/v4.78.0/pnpm-lock.yaml), [chart index](https://langfuse.github.io/langfuse-k8s/index.yaml), [pinned chart metadata](https://github.com/langfuse/langfuse-k8s/blob/langfuse-2.2.4/charts/langfuse/Chart.yaml).

## IDCS and image builds

The chain remains Langfuse custom SSO provider → NextAuth v4 → openid-client v5.7.1. The upstream NextAuth patch adds HTTP proxy and timeout options; it does not replace the native HTTP transport with a redirect-following transport. The custom provider still discovers `${issuer}/.well-known/openid-configuration`.

A local HTTP discovery probe against the exact dependency produced:

```text
unmodified: expected 200 OK, got: 302 Found
follow-redirects transport substitution: discovery succeeds
```

This reproduces a dependency-level incompatibility. It is not an end-to-end IDCS test, nor proof that every IDCS request redirects. Test the actual issuer, discovery, signing-key, token, and optional userinfo requests before deciding the final patch scope. A newer major version of an OpenID library being available does not change the version NextAuth actually uses; replacing v5 with v6 is not a drop-in solution.

The web build also passes `NEXT_PUBLIC_BASE_PATH=/langfuse`. Upstream still reads that value during its Next.js build. Setting it only in runtime Helm values cannot retrofit that path into the stock web image.

Sources: [pinned upstream NextAuth patch](https://github.com/langfuse/langfuse/blob/v4.78.0/patches/next-auth%404.24.15.patch), [custom SSO provider](https://github.com/langfuse/langfuse/blob/v4.78.0/packages/shared/src/server/auth/customSsoProvider.ts), [openid-client request transport](https://github.com/panva/openid-client/blob/v5.7.1/lib/helpers/request.js), [custom base-path requirements](https://langfuse.com/self-hosting/configuration/custom-base-path), [web Dockerfile](https://github.com/langfuse/langfuse/blob/v4.78.0/web/Dockerfile).

### Design choices

| Choice | Benefits | Costs and gates |
| --- | --- | --- |
| Keep custom web build, redirect patch, and `/langfuse` | Preserves current public URLs and IDCS behavior; smallest behavioral change | Continue build maintenance; validate patch against pinned dependency and actual IDCS |
| Adopt stock web image on a dedicated hostname at `/` | Removes web build if all other requirements are met | Changes ingress, URLs, health paths, and IDCS callbacks; must first demonstrate a nonredirecting IDCS flow or upstream-supported equivalent |

Recommendation: first choice for the initial implementation. Upstream worker images are a separate candidate because the OIDC web patch does not itself justify rebuilding the worker. Verify worker base-path assumptions, published platform manifests, and image compatibility before removing that build. The chart defaults advertise `docker.langfuse.com/langfuse/langfuse` and `docker.langfuse.com/langfuse/langfuse-worker`; image digests and architecture support remain unverified.

## Environment and Helm mapping

Preserve these observable workflows: users log in with Oracle IDCS under `/langfuse`; applications ingest and query traces; workers process queues; operators retain Vault secrets, managed Postgres, TLS Redis, OCI Object Storage, and private-registry access. An existing deployment also needs its stored data and API keys preserved.

| Current configuration | v4 / chart v2 assessment and action |
| --- | --- |
| `langfuse.web.image`, `worker.image`, chart-derived application tag | Keep application and chart versions distinct. Pin tested versions and image digests. Preserve OCIR mirroring/access if retained. |
| `NEXT_PUBLIC_BASE_PATH=/langfuse` build argument | Still build-time. Preserve web build and ingress paths for the first pass. |
| `NEXTAUTH_URL`, `langfuse.nextauth.url` | Still supported. Use one Helm source for the existing `/langfuse/api/auth` URL and verify callback `/langfuse/api/auth/callback/custom`. |
| `AUTH_CUSTOM_CLIENT_ID`, `CLIENT_SECRET`, `ISSUER`, `NAME` | Still present in v4 web environment schema. Keep `langfuse-idcs` Secret references. |
| `AUTH_CUSTOM_ID_TOKEN=true`, `AUTH_CUSTOM_ALLOW_ACCOUNT_LINKING=true` | Still supported. Preserve current behavior and test returning-user account linking. |
| `LANGFUSE_CUSTOM_SSO_NAME_CLAIM=sub`, `EMAIL_CLAIM=sub` | Still supported by the shared custom SSO provider. Preserve intentionally; verify claims from the actual IDCS tenant. |
| Username/password disabled, signup flag, telemetry and experimental flags | Preserve the current effective values, including signup currently set to false for `signUpDisabled`; do not infer behavior from contradictory comments. |
| `NODE_ENV=development`, web debug logging | Current values duplicate chart-generated production/info defaults. Use typed `langfuse.nodeEnv` / `logging.level`, with an explicit decision on preserving development/debug behavior versus production settings. |
| `DATABASE_URL` from `langfuse-postgres` | Keep full OCI Postgres TLS connection string. Prefer shared `langfuse.additionalEnv` so web/worker use the same source and chart suppresses its generated database settings. |
| Postgres certificate volume and CSI mount | Preserve Secret names, keys and paths; compare URL certificate paths with actual Secret contents. Current direct secret creation uses `CaCertificate-langfuse.pub`, while comments mention other filenames. |
| `salt`, `encryptionKey`, `nextauth.secret` | Continue explicit existing Secret references. Never accept generated replacements during an upgrade. |
| External Postgres | Keep `postgresql.deploy=false`; repo defaults to Postgres 16. Verify actual service version, TLS, Prisma migrations, and migration-user permissions. |
| External Redis/Valkey TLS | Keep `redis.deploy=false`, hostname, port, TLS and queue behavior. Chart v2 renders `rediss://default@host:6379/0` with current values; explicitly match the managed service's auth/username behavior instead of inheriting new defaults. Repo requests Valkey 7.2. |
| ClickHouse password in `langfuse` Secret | Existing-secret mapping remains available. Validate v4 migration grants for the configured user. |
| Bundled ClickHouse and `clickhouse.zookeeper.resources` | Replace old subchart settings with `clickhouse.cluster.*` and `clickhouse.keeper.*`. Old ZooKeeper settings do not configure Keeper. Explicitly decide replicas, storage, resources, coordination, and OCI storage classes. |
| OCI S3-compatible endpoint, bucket, region, path style and access-key Secrets | Chart v2 retains the `s3` mapping for event/media/batch-export variables. Test upload, read, export and deletion against OCI rather than assuming AWS compatibility. Keep `s3.deploy=false`. |
| `/langfuse/api/public/health` and `/ready`, HPA resources, volumes | Preserve and validate rendered paths, requests/limits, HPA bounds and mounts. Verify metrics availability separately from application readiness. |
| v4 write-mode controls | New explicit decision: use `legacy` then `dual` during existing-data migration; only cut over to `events_only` after validation. Latest inspected source defaults to `events_only`, so omission is not a safe upgrade policy. Set consistently on web and worker. |

Source mapping: [pinned web env schema](https://github.com/langfuse/langfuse/blob/v4.78.0/web/src/env.mjs), [shared env schema](https://github.com/langfuse/langfuse/blob/v4.78.0/packages/shared/src/env.ts), [chart values](https://github.com/langfuse/langfuse-k8s/blob/langfuse-2.2.4/charts/langfuse/values.yaml), [chart env helpers](https://github.com/langfuse/langfuse-k8s/blob/langfuse-2.2.4/charts/langfuse/templates/_helpers.tpl).

### Render-only evidence

Chart 2.2.4 was downloaded directly and its package metadata checked. Current repository values were substituted with dummy hosts and secret references, then rendered with `clickhouse.crdCheck=false` solely for offline rendering. This setting must not silently disable real cluster preflight.

Rendering succeeded, but inspection found duplicate web `NEXTAUTH_URL`, `NODE_ENV`, and `LANGFUSE_LOG_LEVEL`, the Redis connection string above, an empty generated `DATABASE_HOST` alongside our explicit `DATABASE_URL`, and operator-managed ClickHouse/Keeper objects. Successful rendering therefore does not establish runtime compatibility.

## Datastore migration and rollout scope

The current stack uses managed Postgres/Redis and OCI Object Storage, but bundled ClickHouse. A chart-version edit is therefore insufficient for existing deployments. Upstream documents a sibling v2 release and data copy when any bundled store remains. Move the chart/storage deployment while keeping the same application version, then upgrade the application separately. The documented minimum v3 source version is 3.224.1.

V4 additionally requires ClickHouse at least 25.12, Postgres at least 15, and Redis at least 7.0. Pin supported versions and verify live infrastructure. The v2 operator and its ClickHouse/Keeper CRDs need installation and readiness checks; the repo's Helm stage currently skips CRDs and disables hooks. Plan the operator separately instead of assuming that stage installs it.

Preserve the three application secrets, stop or drain ingestion at the defined cutover boundary, validate copied data, and rehearse recovery. Migration work scales with stored data; measure volume and throughput first. Upstream warns historic backfill can require roughly three times current ClickHouse data volume. Do not promise a fixed runtime or copy upstream downtime targets as a guarantee for this tenancy. A v4→v3 rollback after schema changes is not a simple image swap.

Sources: [chart migration guide](https://github.com/langfuse/langfuse-k8s/blob/langfuse-2.2.4/examples/upgrade-v1-to-v2/README.md), [application v3→v4 guide](https://langfuse.com/self-hosting/upgrade/upgrade-guides/upgrade-v3-to-v4).

Recommended scope: fresh v4 deployments first, then a separately rehearsed existing-data migration. Whether both belong in this milestone is pending user input. No live upgrade has been performed.

## OCI GenAI gateway image candidate

The existing gateway source repository advertises `ghcr.io/jin38324/oci-genai-access-gateway:v20251217`. This is a prebuilt-image candidate, not yet a verified replacement. Check actual tag availability, digest, architecture, release provenance, instance-principal support and the existing `AUTH_TYPE`, `OCI_REGION`, `OCI_COMPARTMENT`, `DEFAULT_API_KEYS`, port 8088 and routing contract before adopting it. Do not confuse this OCI gateway with the different Langfuse AI gateway now offered by chart v2. Keep gateway replacement outside the first pass unless explicitly included.

Source: [current gateway upstream README](https://github.com/jin38324/OCI_GenAI_access_gateway#quick-start).

## Phases and verification tasks

### Phase 1 — compatibility assessment
- [x] Isolate a v4 branch without disturbing the existing merge.
- [x] Inspect current image patching, public path and environment mapping.
- [x] Resolve v4 authentication dependencies and inspect upstream patches.
- [x] Reproduce unmodified 302 discovery rejection and patched success locally.
- [x] Download and inspect chart 2.2.4 and render current values offline.
- [x] Identify datastore migration and gateway-image candidates.
- [ ] Confirm initial rollout scope and approve design direction.

### Phase 2 — proposed implementation, after scope approval
- [ ] Pin chart/application/image versions and separate version resolution from shell parsing fallbacks.
- [ ] Update the web build and retain a checked redirect patch for the resolved package.
- [ ] Evaluate upstream worker image separately; keep OCI gateway build unchanged initially.
- [ ] Add operator/CRD sequencing and readiness checks.
- [ ] Map values/env/Secrets/volumes with no duplicate environment names or implicit auth changes.
- [ ] Update defaults, schema descriptions, deployment stages and documentation for the agreed scope.

### Phase 3 — verification gates
- [ ] Offline: format/validate Terraform, lint/render pinned chart, check images/tags, env names and Secret references; reject unknown/obsolete datastore values.
- [ ] OIDC transport: discovery/JWKS/userinfo redirects, token POST semantics, redirect loops/limits, failed tokens and cross-host redirects without credential leakage. Do not treat a browser's normal authorization redirect as the same issue as back-channel HTTP redirects.
- [ ] Fresh isolated OKE deployment: OL8 and OL9 on supported Kubernetes, initial registration, CLI bootstrap and private-image pulls; assert every required operator is ready before Langfuse installation.
- [ ] Real IDCS browser flow: first login, returning user, account linking, logout, callback paths, PKCE/state failures and unchanged claims. User login is required for this gate.
- [ ] Service behavior: Postgres TLS/migrations, Redis TLS/queues, ClickHouse schema/jobs, Object Storage uploads/exports/deletes, telemetry/signup/password flags, ingress/TLS and HPA.
- [ ] Application integration: create project/API keys, ingest and query representative traces/observations, run evaluation through the existing OCI gateway; compare v3/v4 client compatibility.
- [ ] Resilience: credential refresh and reboot, worker retries, node replacement, failed deployment diagnostics and secret reuse after redeploy.
- [ ] Existing-data migration if included: backup/restore rehearsal; pinned v3 chart move; data validation; legacy→dual→events_only cutover; documented recovery boundaries.
- [ ] Commit tested implementation and follow repository merge workflow only after relevant end-to-end validation.

## Open decisions

1. Fresh installs first, or include existing-data migration now?
2. Preserve `/langfuse` and custom web build (recommended), or pursue a hostname/root-path change as a separate image-simplification project?
3. Preserve current development/debug settings exactly, or deliberately switch to production/info?
4. Keep v1 chart support alongside v2, or treat v4 support as a separate deployment track?

No production Terraform files or running services were changed by this assessment.
