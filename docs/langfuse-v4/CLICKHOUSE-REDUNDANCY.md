# ClickHouse redundancy in Langfuse v4

Investigated 2026-11-11 against chart 2.2.4, application 4.77.0 and
ClickHouse operator 0.0.8. Branch: `feature/clickhouse-three-replicas`.

## Findings

The previous chart used one shard and three replicas, not three shards.
The vendored chart 1.5.22 values explicitly set `shards: 1` and
`replicaCount: 3`. Chart 2.2.4 replaces Bitnami ClickHouse/ZooKeeper with
operator-managed ClickHouseCluster/KeeperCluster resources. Its new setting
is `clickhouse.cluster.replicas`, defaulting to 1; Keeper defaults to 3.
Our deployment values did not override the new replica setting. Old Bitnami
keys do not configure the new operator resources.

V4 still does not support multi-shard ClickHouse. The chart template hardcodes
`spec.shards: 1`. Langfuse's normal queries read local tables rather than
routing all reads through distributed tables; splitting data among independent
shards can yield incomplete results. Three replicas retain the entire dataset
on each server, providing redundancy without changing query semantics.

V4's event model consolidates observation data into wide event rows, adds
native JSON/full-text indexing and lightweight updates, and requires
ClickHouse >=25.12. Chart 2.2.4 selects 26.8.36.3. These changes do not introduce
multi-shard routing. `CLICKHOUSE_CLUSTER_ENABLED=true` enables clustered DDL
and replicated table engines; it does not enable sharding. Keeper coordinates
replication and distributed DDL; its three members do not hold three copies
of the ClickHouse analytics dataset.

## Options and decision

- One server plus three Keepers: lower cost, but no redundant analytics copy.
- One shard with three replicas plus three Keepers: restores the old redundancy
  model using the supported chart interface. Selected.
- Three shards: unsupported by Langfuse, and does not itself provide redundancy.

The feature explicitly configures three server replicas, three Keepers, and
required hostname anti-affinity separately for each component. This requires
at least three eligible worker nodes. Server and Keeper may share a node;
replicas of the same component may not. Insufficient capacity leaves pods
Pending instead of silently putting all copies on one host. The selectors use
the operator 0.0.8 app and role labels. The release/CR name is `langfuse`.
This guarantees host separation, not availability-domain separation.

At chart defaults, server storage is 3 x 100 GiB and Keeper storage 3 x 20 GiB;
server requests total 3 CPU / 6 GiB RAM, with 12 GiB aggregate memory limits.
Keeper requests add 0.75 CPU / 768 MiB. Allow headroom for replication catch-up,
queries, merges and web/worker workloads. Replication increases storage and
write work approximately linearly with replica count; it does not triple usable
capacity. Replication is asynchronous by default: this is not a zero-data-loss
write guarantee or a backup.

## Rollout and validation plan

### Phase 1 — implementation

- [x] Inspect old and pinned new chart and current application guidance.
- [x] Set server/Keeper counts and distinct-host scheduling.
- [x] Render charts 1.5.41 and 2.2.4; assert v2 topology and unchanged v1 images.

### Phase 2 — isolated OKE validation (pending)

- [ ] Confirm three eligible nodes, resources and PVC provisioning capacity.
- [ ] Apply through the stack pipeline to the fresh v4 cluster; preserve existing
  CR names, storage and credentials. Do not uninstall the release or delete PVCs.
- [ ] Wait for three Ready servers and three Ready Keepers on distinct hosts.
- [ ] Check `system.clusters` for one shard / three replicas and
  `system.replicas` for non-readonly replicas, empty replication queues and
  no Keeper exceptions after catch-up.
- [ ] Ingest a unique trace and confirm it through Langfuse and on all replicas.
- [ ] Stop one server, then independently one Keeper; verify ingestion/query
  continuity and recovery. Test one worker-node outage to cover both together.
- [ ] Record results, then follow repository review/merge workflow.

Offline command (passed):

```sh
python3 tests/langfuse_chart/check_values_render.py \
  /tmp/langfuse-research/langfuse-1.5.41.tgz \
  /tmp/langfuse-research/langfuse-2.2.4.tgz
```

No infrastructure was changed during this feature work. Scaling an existing v4
cluster needs catch-up validation. Upgrading old Bitnami v3 storage into the
operator is a separate data migration, not a replica-count change.

## Sources

- [Pinned chart values](https://github.com/langfuse/langfuse-k8s/blob/langfuse-2.2.4/charts/langfuse/values.yaml)
- [Pinned cluster template](https://github.com/langfuse/langfuse-k8s/blob/langfuse-2.2.4/charts/langfuse/templates/clickhouse/cluster.yaml)
- [Langfuse ClickHouse configuration, including single-shard restriction](https://langfuse.com/self-hosting/deployment/infrastructure/clickhouse)
- [V4 scaling and event model](https://langfuse.com/self-hosting/configuration/scaling)
- [Operator 0.0.8 pod generation](https://github.com/ClickHouse/clickhouse-operator/blob/v0.0.8/internal/controller/clickhouse/templates.go)
