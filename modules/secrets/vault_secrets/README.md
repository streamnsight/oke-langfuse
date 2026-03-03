# Vault Secrets Module

Creates and ensures OCI Vault secrets from a list of secret specifications. Uses a single external script and returns a map of secret name to OCID.

## Inputs
- `profile`, `compartment_id`, `vault_id`, `key_id`
- `secrets`: list of objects with `name` plus either `value` or `generator`.

## Outputs
- `secret_ocids_by_name`: map of secret name -> OCID
