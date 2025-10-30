![tests](https://github.com/oracle-quickstart/oke-flink/actions/workflows/tests.yaml/badge.svg)

# oke-flink

Deploy a Kubernetes cluster on Oracle Cloud Infrastructure with multiple node pools and add-ons like Apache Flink.

[![Deploy to Oracle Cloud][magic_button]][magic_oke_flink_stack]

## Template Features

The Flink operator deployment is performed by the terraform helm provider, on a cluster templates that can also be used for other purposes.

The OKE cluster template features the following:

- Up to 3 node pools. This allow for usage of different shapes within the same cluster (for example, CPU and GPU, or DenseIO shapes)
- Cluster node-pool auto-scaler, from 0 nodes (shut down) and up, allowing to only use more expensive shapes when needed (i.e. GPU)
- Option to use Secrets encryption.
- Option to enable Image Validation and Pod Admission Controllers.
- Option to install metrics server (required by cluster auto-scaler)
- Option to install cert-manager (required by Flink Operator)
- Option to install a monitoring stack based on Prometheus and Grafana

## Getting started with Apache Flink Operator

The Operator is deployed in the cluster, and offers two modes of operation:

### Application Mode

In this mode flink job are deployed independently, creating a Job Manager and Task Manager(s) for each Job. It is the preferred way of using the operator if the Job code is packaged in a Docker image. In this mode, since a Job Manager is deployed per job, the UI access is also per job and one needs to connect to the specfic Job Manager REST service.

### Session Mode

In session mode, a FlinkDeployment creates a JobManager (or more if High Availability is configured), and then FlinkSessionJob can be created that uses that Job Manager. The advantage is that the UI is accessible in one place, however Job code needs to be staged on a remote location (like an Object Storage bucket). On OCI, the code can be stored on storage bucket and made accessible through a Pre-authenticated Request, or S3 compatibility file system needs to have been configured as a plugin to reference the jar (the difference between the two is in the way to control access)

The demo job referenced in the docs uses Application Mode.

To start a Flink Session Cluster, create a FlinkDeployment without a job field.

For example:

```yaml
apiVersion: flink.apache.org/v1beta1
kind: FlinkDeployment
metadata:
  # the name of the session cluster, to be referenced in the FlinkSessionJob
  name: flink-session
spec:
  image: <flink base image, or your own image with the proper plugins enables, like flink-s3-fs-hadoop>
  flinkVersion: v1_16
  flinkConfiguration:
    taskmanager.numberOfTaskSlots: "2"
    ## S3 compatible mode Object Storage access
    # s3.endpoint: <tenancy_namespace>.compat.objectstorage.us-ashburn-1.oraclecloud.com
    # s3.endpoint.region: us-ashburn-1
    # s3.path.style.access: "true"
    ## state backend for savepoints
    # state.backend: rocksdb
    # state.backend.incremental: "true"
    kubernetes.jobmanager.replicas: "3" # 3 for High Availability
    kubernetes.operator.periodic.savepoint.interval: 1h
    kubernetes.operator.savepoint.history.max.age: 24h
    kubernetes.operator.savepoint.history.max.count: "25"
    ## State storage location
    # state.checkpoints.dir: s3://<state_storage_bucket>/<path>
    # state.savepoints.dir: s3://<state_storage_bucket>/<path>
    # high-availability: org.apache.flink.kubernetes.highavailability.KubernetesHaServicesFactory
    # high-availability.storageDir: s3://<state_storage_bucket>/ha
    rest.flamegraph.enabled: "true"
    restart-strategy: exponential-delay
    metrics.reporters: prom
    metrics.reporter.prom.factory.class: org.apache.flink.metrics.prometheus.PrometheusReporterFactory
  serviceAccount: flink
  podTemplate:
    apiVersion: v1
    kind: Pod
    metadata:
      name: flink-session
    spec:
      serviceAccount: flink
    ## When using your own image, create a secret for OCI Docker Registry, and add it here
    #   imagePullSecrets:
    #   - name: oci-registry
      containers:
        # Do not change the main container name
        - name: flink-main-container
          imagePullPolicy: IfNotPresent
        ## You can pass global env for jobs here
        #   env:
        #   - name: KAFKA_PASSWORD
        #     valueFrom:
        #       secretKeyRef:
        #         name: flink-kafka
        #         key: KAFKA_PASSWORD
        #   - name: AWS_ACCESS_KEY_ID
        #     valueFrom:
        #       secretKeyRef:
        #         name: aws-s3
        #         key: AWS_ACCESS_KEY_ID
        #   - name: AWS_SECRET_ACCESS_KEY
        #     valueFrom:
        #       secretKeyRef:
        #         name: aws-s3
        #         key: AWS_SECRET_ACCESS_KEY
        #   envFrom:
        #   - configMapRef:
        #       name: flink-kafka
  jobManager:
    replicas: 3
    resource:
      memory: "2048m"
      cpu: 1
  taskManager:
    resource:
      memory: "2048m"
      cpu: 1
```

Then a Session Job can be launched with:

```yaml
apiVersion: flink.apache.org/v1beta1
kind: FlinkSessionJob
metadata:
  name: flink-journal
  namespace: flink
spec:
  deploymentName: flink-session # <-- the name of the Session deployment
  job:
    jarURI: # need to use s3:// scheme or https:// and put jar in Object Storage
    parallelism: 2
    ## optional entry class name (full qualified name)
    # entryClass: com.example.MyEntryClass
    ## Command line arguments to pass to the job
    args: []
    upgradeMode: stateless # Use savepoint if state management is configuered. `last-state` is not supported.
```

## Send Flink metrics to Prometheus

To send Flink metrics to Prometheus, some specific configuration is needed in the Flink deployment.

Make sure to add the following to you Flink Session or Application deployment:

```yaml
spec:
  flinkConfiguration:
    metrics.reporters: prom
    metrics.reporter.prom.factory.class: org.apache.flink.metrics.prometheus.PrometheusReporterFactory
```

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

- [Apache Flink operator documentation](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/docs/try-flink-kubernetes-operator/quick-start/)

[magic_button]: https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg
[magic_oke_flink_stack]: https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/oracle-quickstart/oke-flink/releases/latest/download/oke-flink.zip
