# Existing cluster scenarios

These scenarios mix one offline validation case with fixture-backed live OCI compatibility checks.

Current coverage:

- `invalid_empty_cluster_ocid`
- `invalid_basic_cluster_rejected`
- `invalid_two_node_pool`
- `invalid_default_cloud_init`
- `valid_enhanced_three_nodes`

- `invalid_empty_cluster_ocid` is currently the only `fast`-tagged existing-cluster scenario.
- The fixture-backed scenarios are tagged `live` and now declare explicit `infra.profile` metadata so the suite can self-bootstrap and reuse the shared `basic` and `enhanced` fixtures across compatible scenarios.

- The basic and two-node scenarios assert Terraform failures.
- The cloud-init scenarios assert the computed matching-node-pool count directly, because the top-level preflight `check` is not targetable in isolation.
