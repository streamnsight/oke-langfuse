output "details" {
  value = {
    app_id        = local.idcs_app_id
    domain_url    = local.idcs_domain_url
    client_id     = local.idcs_client_id
    client_secret = local.idcs_client_secret
  }
}