![tests](https://github.com/oracle-quickstart/oke-flink/actions/workflows/tests.yaml/badge.svg)

# oke-langfuse

Deploy a Kubernetes cluster on Oracle Cloud Infrastructure with oen or multiple node pools and add-ons, and the Langfuse application for LLM call tracing and evaluation.

[![Deploy to Oracle Cloud][magic_button]][magic_oke_langfuse_stack]

## Template Features

The OKE cluster template features the following:

- Up to 3 node pools. This allow for usage of different shapes within the same cluster (for example, CPU and GPU, or DenseIO shapes)
- Cluster node-pool auto-scaler, from 0 nodes (shut down) and up, allowing to only use more expensive shapes when needed (i.e. GPU)
- Option to use Secrets encryption.
- Option to enable Image Validation and Pod Admission Controllers.
- Option to install metrics server (required by cluster auto-scaler)
- Option to install cert-manager (required by Flink Operator)
- Option to install a monitoring stack based on Prometheus and Grafana

## Getting started with Langfuse on OKE


## Use the Terraform template

To use the Terraform template locally, configure the OCI Command Line Interface with a Private/Public key pair added to your user.

Create a `terraform.tvfars` from the `terraform.tvfars.template` file and fill in the values for the variables.

Run:

```bash
# init the repo
terraform init
# check the plan
terraform plan
# deploy
terraform apply
```

## References

[magic_button]: https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg
[magic_oke_langfuse_stack]: https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/streamnsight/oke-langfuse/releases/latest/download/oke-langfuse.zip
