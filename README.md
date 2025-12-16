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

Before you start, you will need:

- A SSH key (public key) to access the OKE nodes if needed
- A customer key and secret for S3 compatible API (Profile (top right menu) ->  Your User -> Tokens & Keys -> Customer Secret Keys)
- The OCID of your Identity Domain (if you have permission to create apps) OR the informaton about an app created by an admin (Domain URL, App ID, Client id, and Client secret). If you do not control the app, you will also need to have the admin update the Redirect URL once the stack is deployed, with the proper IP address.

When choosing a shape for the OKE nodes, we recommend using `Oracle-Linux 8-10 2025-09-16`, which is the latest OKE optimized image.
Other images will work too. They just do not contain the Kubernetes binaries so that they will tend to be slower to boot / scale up.

IMPORTANT!: Once the stack is deployed, you need to assign users to the IDCS application to get access to Langfuse. If you are not authorized to create the app, you will need to ask you ID Domain admin to do this. Groups can also be allowed, so that users belonging to a group can gain access in bulk.

## Known limitations

- If you are not permitted to create the IDCS/IAM application, you will need to update the app with the redirect URL (see setting up the IDCS App for more details)

- The stack deploys a Public Load Balancer, so the option to allow public load balancers is needed. 
- The Load balancer uses a TLS certificate that is IP based. (Support for domain names wil come later). The Load blaancer uses a dynamic IP, so the Ingress load balancer is first deployed to get an IP address, then the Ingress is updated to use TLS with an IP certtificate provided by Lets Encrypt. IP-certs are not yet production ready, so they are only available through the LetsEncrypt Staging `short-lived` profile. This is coming out soon so this will be updated when it does.

- A customer Client ID and Secret are needed for the S3 compatible access to object storage. That ties the stack to a user, which is not ideal. Until contribution is made to the langfuse project to support native OCI object storage, this is the only way to leverage OCI object storage.

- IDCS appliction is used for SSO: it allows providing access to know users only. The Langfuse user/password auth requires that the subsciption button is allowed to create new users, but that opens the door to anyone being able to create users, so we use IDCS to serve as SSO provider, and limit users to those assigned to the application.

## Setting up the IDCS application

An IDCS / SSO application is required for authentication / authorization.

To create the application if you are not authorized through the stack, provide this information to your ID Domain admin:

- Application Type: Confidential Application
- Application URL: https://*IP-generated-from-the-stack*/langfuse (find the IP in the OUTPUT area of the Resource Manager Stack)
- Select `Enforce grants as authorization` to enforce auth for designated users only. 
- Submit
- Once the app is created, go to OAuth Configuration -> Edit OAuth Configuration
- Click Configure this application as a client now
- Select Authorization Code as the Allowed Grant Type
- Validate

Once the stack is deployed

- Go back to the application and enter the Redirect URL to be https://LANGFUSE_IP/langfuse/api/auth/callback/custom 
- Activate the application
- Go to Users or Groups and add the appropriate users or groups to be authorized to use Langfuse.

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
