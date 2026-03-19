# Existing cluster scenarios

These scenarios focus on fast validation of existing-cluster inputs before we rely on fixture-backed integration coverage.

Current coverage:

- `invalid_missing_cluster_ocid`
- `invalid_empty_cluster_ocid`
- `invalid_basic_cluster_rejected`
- `invalid_public_endpoint`
- `invalid_two_node_pool`
- `invalid_default_cloud_init`
- `valid_enhanced_three_nodes`

The fixture-backed scenarios use the shared `basic` and `enhanced` fixtures to validate existing-cluster compatibility checks against real OCI infrastructure.
