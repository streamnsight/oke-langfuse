locals {
  helm_values = merge(var.helm_values, {})
}
resource "helm_release" "cert_manager" {
  count            = var.enabled ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true
  timeout          = "600"
  wait             = true # wait to allow the webhook to be properly configured

  dynamic "set" {
    for_each = local.helm_values
    content {
      name  = set.key
      value = set.value
    }
  }
}
