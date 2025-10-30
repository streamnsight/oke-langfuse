resource "null" "install_langfuse" {

    # build langfuse image and push to registry
    provisioner "local-exec" {
        command = "./build_langfuse_image.sh"
        # Optional arguments:
        when        = "create"
        on_failure  = "fail"   # or "continue"
        environment = {
          COMPARTMENT_ID = var.compartment_id
          REGION = var.region
          TENANCY_NAMESPACE = data.oci_objectstorage_namespace.ns.namespace
          LANGFUSE_IMAGE_VERSION = "v3.122.1"
          LANGFUSE_K8S_NAMESPACE = "langfuse"
        }
    }

    provisioner "local-exec" {
        command = "./install_langfuse_helm_chart.sh"
        # Optional arguments:
        when        = "create"
        on_failure  = "fail"   # or "continue"
        environment = {
          COMPARTMENT_ID = var.compartment_id
          TENANCY_NAMESPACE = data.oci_objectstorage_namespace.ns.namespace
          LANGFUSE_DEPLOYMENT_NAME = "langfuse"
          LANGFUSE_K8S_NAMESPACE = "langfuse"
        }
    }
}