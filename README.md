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

- The stack deploys a Public Load Balancer, so the option to allow public load balancers is needed. This is because IDCS, as well as LetsEncrypt providing the public TLS cert, need to be able to reach the instance.

- The Load balancer uses a TLS certificate that is IP based. (Support for domain names will come later). The Load balancer uses a dynamic IP. The Gateway resource is used to deploy the OCI Load Balancer, and is deployed first. The IP is gathered from this deployed load balancer and the certificate request is made via Let's Encrypt. IP-certs are only available through the LetsEncrypt `short-lived` profile, so the ClusterIssuer resource includes this profile name. 

- Important note about cert-manager: cert-manager manages the TLS cert and its renewall. cert-manager is deployed in the OKE cluster using the OKE cluster add-on method. This means it is managed by OKE. However, its deployment had been needing a patch to work with the Gateway resource, so if for some reason the certificate does not update, you may need to repatch the cert-manager deployment with the arg `--enable-gateway-api`.
The reason we use Gateway is because Ingress does not support IP cert, because the host in an Ingress rule cannot be an IP address. Including the flag by default is in the OKE roadmap.

- A customer Client ID and Secret are needed for the S3 compatible access to object storage. That ties the stack to a user, which is not ideal. Until contribution is made to the langfuse project to support native OCI object storage, this is the only way to leverage OCI object storage at this point.

- IDCS appliction is used for SSO: it allows providing access to know users only. The Langfuse user/password auth requires that the subsciption button is allowed to create new users, but that opens the door to anyone being able to create users, so we use IDCS to serve as SSO provider, and limit users to those assigned to the application.

## Setting up the IDCS application

An IDCS / SSO application is required for authentication / authorization.

To create the application if you are not authorized through the stack, provide this information to your ID Domain admin:

- Application Type: `Confidential Application`
- Application URL: https://*IP-generated-from-the-stack*/langfuse (find the IP in the OUTPUT area of the Resource Manager Stack). You will not know this information until after you deploy the stack, but you cannot deploy without the app info, so this will need to be updated after you deploy the stack.
- Select `Enforce grants as authorization` to enforce auth for designated users only. If not set, this will allow access to anyone in the domain without being part of a group or being specifically added (less secure).
- Submit
- Once the app is created, go to **OAuth Configuration** -> **Edit OAuth Configuration**
- Click Configure this application as a client now
- Select `Authorization Code` as the `Allowed Grant Type`
- Validate

Once the stack is deployed

- Go back to the application and enter the Redirect URL to be https://LANGFUSE_IP/langfuse/api/auth/callback/custom 
- Activate the application
- Go to Users or Groups and add the appropriate users or groups to be authorized to use Langfuse.

## Configuring LLM models in Langfuse

In Langfuse, to access LLMs for evaluation (LLM-as-Judge) with traces and datasets, you need to setup model access.

OCI model access is via the OCI GenaAI Gateway project (which is NOT an OCI service, but an open source proxy to mimic OpenAI)

Note: as of Jan 23rd 2026, OCI Generative AI offers the API keys service, which can be used instead of the below (for Meta LLama, xAI Grok and openAI GPT models only). For Cohere and other models, the gateway is still needed at this point.

In the `LLM Connections` of your Langfuse project settings:

- Click `+Add LLM Connection`
- Choose OpenAI as the LLM adapter
- name your provider (ex. OCI)
- For all models, for `API Key`, use the value you find in the OUTPUT area of the resource manager stack for DEFAULT_API_KEYS. If using OCI API Keys, use an API Key you created in the Generative AI console area.
- Click *Show Advanced Settings*
- for API Base URL use: `http://oci-genai-gateway:8088/v1`. If you use an OCI Generative AI API Keys, use `https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/v1` instead.
- Uncheck *Enable default models*
- Enter the models you want to use (ex xai.grok-3, xai.grok-4-fast-reasoning, cohere.command-a-03-2025, openai.gpt-oss-120b etc.)
- Click *Create Connection*


## Using the Terraform template locally

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


## How to Launch the application (Langfuse)

Refer the detailed documentation [here](docs/howto.md).


## References

[magic_button]: https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg
[magic_oke_langfuse_stack]: https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/streamnsight/oke-langfuse/releases/latest/download/oke-langfuse.zip


# TODO

- offer choice of self signed cer, IP cert or domain name cert for TLS
- look into OSS native client using workload identity.
- debug policies for deployment across compartment (devops, cluster, vcn)
