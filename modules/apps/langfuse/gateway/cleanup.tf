

resource "null_resource" "destroy_load_balancer" {
  triggers = {
    cluster_id     = var.cluster_id
    compartment_id = var.compartment_id
  }
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-CMD
      set +e

      LB_IDS=$(oci lb load-balancer list \
        --compartment-id ${self.triggers.compartment_id} \
        --all \
        --query "data[?\"defined-tags\".\"Oracle-Tags\".\"CreatedBy\"=='${self.triggers.cluster_id}' && \"freeform-tags\".source=='istio-gateway'].id | join(' ', @)" \
        --raw-output)

      if [ -z "$LB_IDS" ]; then
        echo "No matching load balancer found; nothing to delete."
        exit 0
      fi

      for id in $LB_IDS; do
        echo "Deleting load balancer $id"
        oci lb load-balancer delete --load-balancer-id "$id" --force
      done
    CMD
  }
}
