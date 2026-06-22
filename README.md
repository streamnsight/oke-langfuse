# oke-langfuse

This OCI Resource Manager (Terraform) stack automates deployment of the Langfuse Helm chart on OKE. It provisions the required infrastructure, deploys a Kubernetes cluster, and supporting add-ons and DevOps pipelines to automae deployment of the Langfuse open-source version.

🚨 **Important:** Read the caveats and limitations before deploying.

The stack can deploy into an existing VCN or create all networking (VCN, subnets, security lists, etc.) from scratch. It supports one or more node pools and installs cluster add-ons, then deploys Langfuse for LLM call tracing and evaluation.

It can also deploy into an existing OKE cluster by setting:

- `use_existing_cluster = true`
- `cluster_ocid = "ocid1.cluster..."`

When using an existing cluster, this stack validates that the target cluster is compatible:

- cluster type must be `ENHANCED_CLUSTER`
- Kubernetes endpoint must be private (`is_public_ip_enabled = false`)
- at least one existing node pool must already have 3 or more nodes

In existing-cluster mode, this stack does **not** create cluster/node pools and does **not** deploy or manage cluster autoscaler. It skips OKE managed add-ons that are already present for the existing-cluster add-ons it does manage.

[![Deploy to Oracle Cloud][magic_button]][magic_oke_langfuse_stack]

## Known limitations

- Cross-compartment deployments are not supported. Networking, DevOps, Vault, and the deployment must be in the same compartment.
- If you cannot create the IDCS/IAM application due to lack of permissions, get the app information from your Domain Administrator, and have them update the redirect URL and add users after deployment (see below).
- 🚨 The Identity Domain must have the **Access signing certificate** option **enabled**. 
- The stack deploys a **public** load balancer. Public access is required for IDCS and for the default Let’s Encrypt IP certificate flow.
- By default, the load balancer uses an **IP-based** TLS certificate. The Gateway resource provisions the LB, then the IP is used to request a Let’s Encrypt certificate.
  - Let’s Encrypt IP certificates are **short-lived** (7 days).
  - 🚨 Blocking public access to the Langfuse UI will prevent IP certificate renewal.
  - For production custom domains, use a custom-domain TLS mode instead of the default IP certificate flow.
- Custom domains and TLS are configured separately. Custom-domain TLS can use an OCI Certificates Service certificate OCID, PEM material imported into OCI Certificates Service, or Let’s Encrypt HTTP01.
  - Let’s Encrypt HTTP01 for custom domains does not require an OCI DNS01 webhook, but the domain must resolve to the Langfuse load balancer IP and port 80 must be publicly reachable.
  - The first deployment can create the load balancer before DNS is pointed at it. After you create the DNS A/AAAA record, cert-manager should continue the HTTP01 flow without rerunning the OCI DevOps pipeline.
  - If an ACME order reaches a terminal failed state before DNS is fixed, delete the failed `Order`, `Challenge`, or `CertificateRequest` in the `langfuse` namespace and cert-manager will recreate it.
- cert-manager is installed as an OKE add-on (OKE-managed) and its deployment is patched with `--enable-gateway-api` to support Gateway-based certificates. This is expected to become the default in a future OKE release. However, in the mean time, if the cert-manager was to update, this flag may need to be re-patched in the cert-manager deployment for the certificate to update properly. The version is fixed to v1.19.2 to avoid auto-update.
- S3-compatible access requires a Customer Secret Key tied to a user. If that user is removed, Langfuse will lose access to the bucket.
- IDCS is used for SSO to avoid open self-signup. Langfuse’s built-in auth allows user self-registration, which is not desirable for controlled access, and that feature is de-activated in favor of SSO.
- 🚨 There is some issue in Langfuse with the S3 compatible API secret and access key [https://github.com/langfuse/langfuse/issues/8449](https://github.com/langfuse/langfuse/issues/8449). When the secret has special characters, esp. the (+) sign, it will fail. WHen creating you Customer secret, if the secret contains those character, delete it and recreate a new one so it does not have tose characters.

## Getting started with Langfuse on OKE

Before you start, you will need:

- An SSH public key (for node access if needed)
- A Customer Secret Key for S3-compatible access (Profile → Your User → Tokens & Keys → Customer Secret Keys)
- A Vault and Encryption Key in the target compartment
- The Identity Domain OCID **or** details for an existing app (Domain URL, App ID, Client ID, Client Secret)
  - If you do not control the app, an admin must update the redirect URL after deployment

For stack-managed node pools, the normal path is to set `np*_operating_system` and `np*_operating_system_version`. The stack resolves an OKE-ready worker image from those inputs, the node shape, and the selected Kubernetes version.

If you need to force a custom image OCID, set `np*_image_override = true` and then provide `np*_image_id`. The `np*_image_id` value is ignored unless the matching override flag is enabled. This is intentional so stale saved image IDs from older stack versions do not silently affect image selection.

Custom images may work, but non-OKE-ready images will usually boot and scale more slowly because Kubernetes binaries are not preinstalled.

⚠️ **Important:** When the stack creates the IDCS application, it automatically assigns the launching Resource Manager user by default. Any additional users or groups must still be assigned to the application after deployment. If you cannot create the app, ask your Identity Domain admin to assign access manually.

## Custom domain and TLS

The stack can expose Langfuse at your own FQDN. Domain selection and TLS mode are configured separately.

By default, TLS is enabled. Without a custom domain, the stack requests a Let's Encrypt IP certificate.

Recommended secure option for production:

1. In the OCI Console, go to **Identity & Security** -> **Certificates**.
2. Create or import a leaf certificate for your Langfuse FQDN, for example `langfuse.example.com`.
3. When importing, provide the public leaf certificate, the matching private key, and the intermediate certificate chain.
4. Wait until the certificate is **Active** and confirm it is in the same region as the Langfuse load balancer.
5. Copy the certificate OCID.
6. In the stack, enable `langfuse_use_custom_domain`, set `langfuse_custom_domain_fqdn`, set `langfuse_has_provided_certificate = true`, select `existing_oci_certificate`, and paste the OCID into `langfuse_certificate_ocid`.

Convenience option:

- Set `langfuse_has_provided_certificate = true`, select `import_certificate_pem`, and provide `langfuse_certificate_pem`, `langfuse_private_key_pem`, and `langfuse_certificate_chain_pem`.
- The stack imports that material into OCI Certificates Service and uses the created certificate OCID for the load balancer.
- This is less secure than pre-importing the certificate because private key material is passed through Resource Manager/Terraform and may be retained in Terraform state or stack history.

Let’s Encrypt HTTP01 option:

- Leave `langfuse_has_provided_certificate = false` for a custom-domain Let’s Encrypt certificate without DNS01 automation. The only supported challenge type today is `http01`; DNS01 will be added later.
- After the load balancer is created, point your domain DNS `A` record at `langfuse_load_balancer_ip`. cert-manager should continue the HTTP01 flow once DNS resolves to the load balancer.

DNS is manual in this release. After deployment, use the `langfuse_load_balancer_ip` output and create or update your DNS `A` record so `langfuse_custom_domain_fqdn` points to that IP.

## Setting up the IDCS application

An IDCS / SSO application is required for authentication and authorization.

If you are an Identity Domain admin, the app will be created and configured for you, and named Langfuse-<deploymentID>. By default, the Resource Manager user launching the stack is also assigned to that app automatically.

🚨 **Important:** The Identity Domain must have **Access signing certificate** option **enabled**. (In Identity Domain -> Settings tab -> Domain Settings -> Edit Domain Settings)

If this is not the case, you may encounter an **OAuthCallBack error** in Langfuse when trying to login.

If you are not authorized to create the application through the stack, a Domain Administrator will need to create the app and configure it for you. 

Provide the following information to your Identity Domain admin:

- The Identity Domain must have **Access signing certificate** option **enabled**. (In Identity Domain -> Settings tab -> Domain Settings -> Edit Domain Settings)

To create the app:
- Application Type: `Confidential Application`
- Application URL: `https://<irrelevant>/langfuse` (The URL is required but we don't know the IP until after stack deploy, so it should be anything and replaced later)
- Select **Enforce grants as authorization** to restrict access to assigned users/groups

Create the app then:

- Go to **OAuth Configuration** → **Edit OAuth Configuration**
- Click **Configure this application as a client now**
- Select `Authorization Code` as the **Allowed Grant Type**
- Save

After the stack is deployed, go back to your Domain administrator for them to:

- Update the Redirect URL in the OAuth Configuration to `https://<LANGFUSE_IP>/langfuse/api/auth/callback/custom`
- Activate the application (Top right button drop down)
- Assign users or groups to the application (Users tab)

For local Terraform runs, `current_user_ocid` is not injected automatically. If you want the same auto-assignment behavior outside Resource Manager, provide `current_user_ocid` explicitly and keep `create_idcs_app = true`.

## Configuring LLM models in Langfuse

To evaluate LLMs (LLM-as-Judge) with traces and datasets, configure model access in Langfuse.

OCI model access is provided by the OCI GenAI Gateway (an open-source proxy that mimics the OpenAI API). As of Jan 23, 2026, OCI Generative AI also supports API keys for some models (Meta Llama, xAI Grok, OpenAI GPT). For Cohere and others, the gateway is still required.

In **Project Settings → LLM Connections**:

- Click **+ Add LLM Connection**
- Choose **OpenAI** as the adapter
- Name your provider (e.g., `OCI`)
- For **API Key**:
  - Use `DEFAULT_API_KEYS` from the Resource Manager stack outputs, **or**
  - Use an OCI Generative AI API Key (if supported for your model)
- Click **Show Advanced Settings**
- Set **API Base URL**:
  - `http://oci-genai-gateway:8088/v1` (gateway)
  - `https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/v1` (OCI API Keys)
- Uncheck **Enable default models**
- Enter your model IDs (e.g., `xai.grok-3`, `cohere.command-a-03-2025`, `openai.gpt-oss-120b`)
- Click **Create Connection**

## Template Features

The OKE cluster template includes:

- Up to 3 node pools to mix shapes (CPU, GPU, DenseIO, etc.)
- Cluster autoscaler from 0 nodes up to the configured maximum
- Metrics Server (required by the autoscaler)
- cert-manager (required for Let’s Encrypt certificates)

The DevOps pipelines use manifest deployment, and shell stage deployment. Some manifests cannot be deployed in manifest deployemnt stages due to some CRD access limitations in those pipelines.


## Using the Terraform template locally

Configure the OCI CLI with a user that has a Private/Public key pair. Then create a `terraform.tfvars` file based on `terraform.tfvars.example` and fill in the required values.

The OCI profile **must be** `DEFAULT` (some modules do not support custom profiles).

Run:

```bash
# init the repo
terraform init
# check the plan
terraform plan
# deploy
terraform apply
```

## How to launch the application (Langfuse)

Refer to the detailed documentation [here](docs/howto.md).


## Deploying on an existing cluster

To deploy on an existing cluster, the nodes need to be able to pull images from OCI Container Registry.
To do so, the nodes usually need a cloud-init script that periodically logs into the container registry
and stores those credentials into the node docker config.

The init script used in this stack, when deploying a new OKE cluster is in the root folder (`cloud-init.sh`)

The stack DOES NOT attempt to modify an existing cluster cloud-init for obvious reasons, but it WILL FAIL if it does not have proper permission to pull images from OCIR.

The stack already validates that an existing cluster is an `ENHANCED_CLUSTER`, uses a private endpoint, and has at least one node pool with 3 or more nodes.

If you want a faster preflight before the long deployment path starts, you can also enable:

```hcl
use_existing_cluster                         = true
cluster_ocid                                 = "ocid1.cluster..."
enable_existing_cluster_cloud_init_preflight = true
```

When enabled, Terraform inspects every eligible existing node pool with at least three nodes, decodes `node_metadata.user_data`, and checks for OCIR bootstrap markers that distinguish this stack's custom cloud-init from the default OKE init.

By default the preflight looks for the stack's docker login path, docker credential helper bootstrap path, and the recurring docker-login cron command. If your existing cluster uses a different but still valid bootstrap implementation, you can tune the check with `existing_cluster_cloud_init_required_markers`.


## References

[magic_button]: https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg
[magic_oke_langfuse_stack]: https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/streamnsight/oke-langfuse/releases/latest/download/oke-langfuse.zip

# TODO

- [X] container vulnerability scanning
- [X] build worker image
- [X] SSL Cert: IP cert
- [ ] SSL cert: self-signed, 
- [ ] SSL cert: domain / DNS based certificates
- [ ] OSS native client support using workload identity (PR here [12379](https://github.com/langfuse/langfuse/pull/12379))
- [X] ensure cloud-init provisions OCIR login script + cronjob
- [X] Vault secrets
- [ ] support cross compartment deployments, policies for cross-compartment deployment (DevOps, cluster, VCN)
- [X] Support deployment on existing cluster
- [X] look up available shell stages shapes and choose from those only.
- [ ] 'latest' as langfuse helm chart option (lookup and use latest)
- [ ] auto add group and user to IDCS app
- [ ] Cache users / ACLs to restrict cluster access
- [ ] use existing Cache cluster
- [ ] Postgres users ACLs
- [ ] validate deployment from local with profile
- [ ] ClickHouse dedicated node-pool
