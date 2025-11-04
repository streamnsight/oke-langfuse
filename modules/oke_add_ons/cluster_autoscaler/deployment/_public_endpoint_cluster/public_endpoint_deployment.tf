locals {
  nodes = [for k, v in var.autoscaler_pool_settings : try(lookup(v, "autoscale", false), false) ? "--nodes=${try(lookup(v, "min_nodes", 0), 0)}:${try(lookup(v, "max_nodes", 499), 499)}:${try(lookup(v, "id", ""), "")}" : ""]
  env_dyngroup = {
    "OKE_USE_INSTANCE_PRINCIPAL" = "true",
    "OCI_SDK_APPEND_USER_AGENT"  = "oci-oke-cluster-autoscaler"
  }
  env_workload_id = {
    "OCI_USE_WORKLOAD_IDENTITY"      = "true",
    "OCI_RESOURCE_PRINCIPAL_VERSION" = "2.2",
    "OCI_RESOURCE_PRINCIPAL_REGION"  = "${var.region}",
    "OKE_USE_INSTANCE_PRINCIPAL"     = "false",
    "OCI_SDK_APPEND_USER_AGENT"      = "oci-oke-cluster-autoscaler",
    "OCI_COMPARTMENT_ID"             = "${var.compartment_id}"
  }
}

module "container_image" {
  source             = "../../image"
  kubernetes_version = var.kubernetes_version
  ocir_region        = "us-ashburn-1"
}


resource "kubernetes_service_account_v1" "cluster_autoscaler_sa" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }
  automount_service_account_token = false

}

resource "kubernetes_secret" "cluster_autoscaler_sa_token" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "cluster-autoscaler-token"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = "cluster-autoscaler"
    }
  }
  type = "kubernetes.io/service-account-token"

}

resource "kubernetes_cluster_role" "cluster_autoscaler_cr" {
  count = var.enabled ? 1 : 0

  metadata {
    name = "cluster-autoscaler"
    labels = {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["events", "endpoints"]
    verbs      = ["create", "patch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/eviction"]
    verbs      = ["create"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/status"]
    verbs      = ["update"]
  }
  rule {
    api_groups     = [""]
    resource_names = ["cluster-autoscaler"]
    resources      = ["endpoints"]
    verbs          = ["get", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["watch", "list", "get", "patch", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes", "namespaces"]
    verbs      = ["watch", "list", "get"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["replicasets", "daemonsets"]
    verbs      = ["watch", "list", "get"]
  }
  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "replicasets", "daemonsets"]
    verbs      = ["watch", "list", "get"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses", "csinodes", "csistoragecapacities", "csidrivers"]
    verbs      = ["watch", "list", "get"]
  }
  rule {
    api_groups = ["batch", "extensions"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "patch"]
  }
  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["create"]
  }
  rule {
    api_groups     = ["coordination.k8s.io"]
    resource_names = ["cluster-autoscaler"]
    resources      = ["leases"]
    verbs          = ["get", "update"]
  }
}

resource "kubernetes_role" "cluster_autoscaler_role" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create", "list", "watch"]
  }
  rule {
    api_groups     = [""]
    resource_names = ["cluster-autoscaler-status", "cluster-autoscaler-priority-expander"]
    resources      = ["configmaps"]
    verbs          = ["delete", "get", "update", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "cluster_autoscaler_crb" {
  count = var.enabled ? 1 : 0
  metadata {
    name = "cluster-autoscaler"
    labels = {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-autoscaler"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "cluster-autoscaler"
    namespace = "kube-system"
  }
}

resource "kubernetes_role_binding" "cluster_autoscaler_rb" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "cluster-autoscaler"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "cluster-autoscaler"
    namespace = "kube-system"
  }
}

resource "kubernetes_deployment" "cluster_autoscaler_deployment" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    labels = {
      app = "cluster-autoscaler"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "cluster-autoscaler"
      }
    }

    template {
      metadata {
        labels = {
          app = "cluster-autoscaler"
        }
        annotations = {
          "prometheus.io/scrape" = true
          "prometheus.io/port"   = 8085
        }
      }

      spec {
        service_account_name = "cluster-autoscaler"

        container {
          image = module.container_image.ca_image
          name  = "cluster-autoscaler"

          resources {
            limits = {
              cpu    = "100m"
              memory = "300Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "300Mi"
            }
          }
          command = compact(flatten([
            "./cluster-autoscaler",
            "--v=${var.cluster_autoscaler_log_level_verbosity}",
            "--stderrthreshold=info",
            "--cloud-provider=${module.container_image.ca_provider}",
            "--max-node-provision-time=${var.cluster_autoscaler_max_node_provision_time}m",
            local.nodes,
            "--scale-down-delay-after-add=${var.cluster_autoscaler_scale_down_delay_after_add}m",
            "--scale-down-unneeded-time=${var.cluster_autoscaler_scale_down_unneeded_time}m",
            "--unremovable-node-recheck-timeout=${var.cluster_autoscaler_unremovable_node_recheck_timeout}m",
            "--balance-similar-node-groups",
            "--balancing-ignore-label=displayName",
            "--balancing-ignore-label=hostname",
            "--balancing-ignore-label=internal_addr",
            "--balancing-ignore-label=oci.oraclecloud.com/fault-domain"
          ]))
          image_pull_policy = "Always"
          dynamic "env" {
            for_each = var.cluster_autoscaler_use_workload_identity ? local.env_workload_id : local.env_dyngroup
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
  # lifecycle {
  #   ignore_changes = [
  #     spec[0].template[0].spec[0].container[0].env
  #   ]
  # }
}

resource "kubernetes_pod_disruption_budget_v1" "core_dns_pod_disruption_budget" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "coredns-pdb"
    namespace = "kube-system"
    labels = {
      k8s-app = "cluster-autoscaler"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        k8s-app = "kube-dns"
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "cluster_autoscaler_pod_disruption_budget" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "cluster-autoscaler-pdb"
    namespace = "kube-system"
    labels = {
      k8s-app = "cluster-autoscaler"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        app = "cluster-autoscaler"
      }
    }
  }
}
