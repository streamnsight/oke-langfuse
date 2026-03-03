
module "oci_genai_gateway_vault_secrets" {
  source = "../../secrets/vault_secrets"

  profile        = var.oci_profile
  compartment_id = var.secrets_store_vault_compartment_id
  vault_id       = var.secrets_store_vault_id
  key_id         = var.secrets_store_key_id

  secrets = [
    {
      name      = "${var.deploy_id}_OCI_GENAI_GATEWAY_DEFAULT_API_KEY"
      generator = { type = "openssl_hex", bytes = 56 }
    }
  ]
}
