## This module creates an Identity Domain app integration to provide SSO capability

# Look up identity domain info
data "oci_identity_domain" "identity_domain" {
  domain_id = var.identity_domain_id
}

# Look up Application info (once created)
data "oci_identity_domains_app" "idcs_app" {
  #Required
  app_id        = oci_identity_domains_app.idcs_app.id
  idcs_endpoint = data.oci_identity_domain.identity_domain.url
}

## For debuging
# output "idcs" {
#   value = data.oci_identity_domains_app.idcs_app
# }

locals {
  idcs_app_id        = oci_identity_domains_app.idcs_app.id
  idcs_domain_url    = data.oci_identity_domain.identity_domain.url
  idcs_client_id     = data.oci_identity_domains_app.idcs_app.name
  idcs_client_secret = data.oci_identity_domains_app.idcs_app.client_secret
}

# Create IDCS app
resource "oci_identity_domains_app" "idcs_app" {
  #Required
  based_on_template {
    #Required
    value = "CustomWebAppTemplateId"

    #Optional
    # well_known_id = "CustomWebAppTemplateId"
  }
  display_name  = var.display_name
  idcs_endpoint = data.oci_identity_domain.identity_domain.url
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:App", "urn:ietf:params:scim:schemas:oracle:idcs:extension:OCITags"]

  #Optional
  # access_token_expiry = var.app_access_token_expiry
  active = "true" # set the app as active
  # alias_apps {
  #     #Required
  #     value = var.app_alias_apps_value
  # }
  # all_url_schemes_allowed = var.app_all_url_schemes_allowed
  allow_access_control = "true" # enforce grant as authorization
  # allow_offline = var.app_allow_offline
  allowed_grants = ["authorization_code"] # use authorization code grant type (for Langfuse) 
  # allowed_operations = var.app_allowed_operations
  # allowed_scopes {
  #     #Required
  #     fqs = var.app_allowed_scopes_fqs
  # }
  # allowed_tags {
  #     #Required
  #     key = var.app_allowed_tags_key
  #     value = var.app_allowed_tags_value
  # }
  # app_icon = var.app_app_icon
  # # app_signon_policy {
  # #     #Required
  # #     value = var.app_app_signon_policy_value
  # # }
  # app_thumbnail = var.app_app_thumbnail
  # apps_network_perimeters {
  #     #Required
  #     value = var.app_apps_network_perimeters_value
  # }
  # as_opc_service {
  #     #Required
  #     value = var.app_as_opc_service_value
  # }
  # attr_rendering_metadata {
  #     #Required
  #     name = var.app_attr_rendering_metadata_name

  #     #Optional
  #     datatype = var.app_attr_rendering_metadata_datatype
  #     helptext = var.app_attr_rendering_metadata_helptext
  #     label = var.app_attr_rendering_metadata_label
  #     max_length = var.app_attr_rendering_metadata_max_length
  #     max_size = var.app_attr_rendering_metadata_max_size
  #     min_length = var.app_attr_rendering_metadata_min_length
  #     min_size = var.app_attr_rendering_metadata_min_size
  #     order = var.app_attr_rendering_metadata_order
  #     read_only = var.app_attr_rendering_metadata_read_only
  #     regexp = var.app_attr_rendering_metadata_regexp
  #     required = var.app_attr_rendering_metadata_required
  #     section = var.app_attr_rendering_metadata_section
  #     visible = var.app_attr_rendering_metadata_visible
  #     widget = var.app_attr_rendering_metadata_widget
  # }
  # attribute_sets = ["all"]
  # attributes = ""
  # audience = var.app_audience
  # authorization = var.app_authorization
  # bypass_consent = var.app_bypass_consent
  # certificates {
  #     #Required
  #     cert_alias = var.app_certificates_cert_alias
  # }
  # client_ip_checking = var.app_client_ip_checking
  client_type = "confidential" # create a Confidential Application
  # contact_email_address = var.app_contact_email_address
  # delegated_service_names = var.app_delegated_service_names
  # description = var.app_description
  # disable_kmsi_token_authentication = var.app_disable_kmsi_token_authentication
  # error_page_url = var.app_error_page_url
  # force_delete = var.app_force_delete
  # home_page_url = var.app_home_page_url
  # icon = var.app_icon
  # id = var.app_id
  # id_token_enc_algo = var.app_id_token_enc_algo
  # identity_providers {
  #     #Required
  #     value = var.app_identity_providers_value
  # }
  # idp_policy {
  #     #Required
  #     value = var.app_idp_policy_value
  # }
  # is_alias_app = var.app_is_alias_app
  # is_enterprise_app = var.app_is_enterprise_app
  # is_form_fill = var.app_is_form_fill
  # is_kerberos_realm = var.app_is_kerberos_realm
  # is_login_target = var.app_is_login_target
  # is_mobile_target = var.app_is_mobile_target
  # is_multicloud_service_app = var.app_is_multicloud_service_app
  is_oauth_client = "true" # set as OAuth Client app
  # is_oauth_resource = var.app_is_oauth_resource
  # is_obligation_capable = var.app_is_obligation_capable
  # is_radius_app = var.app_is_radius_app
  # is_saml_service_provider = var.app_is_saml_service_provider
  # is_unmanaged_app = var.app_is_unmanaged_app
  # is_web_tier_policy = var.app_is_web_tier_policy
  # landing_page_url = var.app_landing_page_url
  # linking_callback_url = var.app_linking_callback_url
  # login_mechanism = var.app_login_mechanism
  # login_page_url = var.app_login_page_url
  # logout_page_url = var.app_logout_page_url
  # logout_uri = var.app_logout_uri
  name = var.display_name
  # ocid = var.app_ocid
  # post_logout_redirect_uris = var.app_post_logout_redirect_uris
  # privacy_policy_url = var.app_privacy_policy_url
  # product_logo_url = var.app_product_logo_url
  # product_name = var.app_product_name
  # protectable_secondary_audiences {
  #     #Required
  #     value = var.app_protectable_secondary_audiences_value
  # }
  # radius_policy {
  #     #Required
  #     value = var.app_radius_policy_value
  # }
  redirect_uris = [var.redirect_url] #call back URL for Langfuse
  #var.app_redirect_uris
  # refresh_token_expiry = var.app_refresh_token_expiry
  # resource_type_schema_version = var.app_resource_type_schema_version
  # saml_service_provider {
  #     #Required
  #     value = var.app_saml_service_provider_value
  # }
  # scopes {
  #     #Required
  #     value = var.app_scopes_value

  #     #Optional
  #     description = var.app_scopes_description
  #     display_name = var.app_scopes_display_name
  #     requires_consent = var.app_scopes_requires_consent
  # }
  # secondary_audiences = ["secondaryAudiences"]
  # service_params {
  #     #Required
  #     name = var.app_service_params_name

  #     #Optional
  #     value = var.app_service_params_value
  # }
  # service_type_urn = var.app_service_type_urn
  # service_type_version = var.app_service_type_version
  show_in_my_apps = "true"
  # signon_policy {
  #     #Required
  #     value = var.app_signon_policy_value
  # }
  # tags {
  #     #Required
  #     key = var.app_tags_key
  #     value = var.app_tags_value
  # }
  # terms_of_service_url = var.app_terms_of_service_url
  # terms_of_use {
  #     #Required
  #     value = var.app_terms_of_use_value
  # }
  # trust_policies {
  #     #Required
  #     value = var.app_trust_policies_value
  # }
  # trust_scope = var.app_trust_scope
  # urnietfparamsscimschemasoracleidcsextension_oci_tags {

  #     #Optional
  #     defined_tags {
  #         #Required
  #         key = var.app_urnietfparamsscimschemasoracleidcsextension_oci_tags_defined_tags_key
  #         namespace = var.app_urnietfparamsscimschemasoracleidcsextension_oci_tags_defined_tags_namespace
  #         value = var.app_urnietfparamsscimschemasoracleidcsextension_oci_tags_defined_tags_value
  #     }
  #     freeform_tags {
  #         #Required
  #         key = var.app_urnietfparamsscimschemasoracleidcsextension_oci_tags_freeform_tags_key
  #         value = var.app_urnietfparamsscimschemasoracleidcsextension_oci_tags_freeform_tags_value
  #     }
  # }
  # urnietfparamsscimschemasoracleidcsextensiondbcs_app {

  #     #Optional
  #     domain_app {
  #         #Required
  #         value = var.app_urnietfparamsscimschemasoracleidcsextensiondbcs_app_domain_app_value
  #     }
  #     domain_name = "domainName"
  # }
  # urnietfparamsscimschemasoracleidcsextensionenterprise_app_app {

  #     #Optional
  #     allow_authz_decision_ttl = var.app_urnietfparamsscimschemasoracleidcsextensionenterprise_app_app_allow_authz_decision_ttl
  #     allow_authz_policy {
  #         #Required
  #         value = var.app_urnietfparamsscimschemasoracleidcsextensionenterprise_app_app_allow_authz_policy_value
  #     }
  #     app_resources {
  #         #Required
  #         value = var.app_urnietfparamsscimschemasoracleidcsextensionenterprise_app_app_app_resources_value
  #     }
  #     deny_authz_decision_ttl = var.app_urnietfparamsscimschemasoracleidcsextensionenterprise_app_app_deny_authz_decision_ttl
  #     deny_authz_policy {
  #         #Required
  #         value = var.app_urnietfparamsscimschemasoracleidcsextensionenterprise_app_app_deny_authz_policy_value
  #     }
  # }
  # urnietfparamsscimschemasoracleidcsextensionform_fill_app_app {

  #     #Optional
  #     configuration = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_app_configuration
  #     form_cred_method = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_app_form_cred_method
  #     form_credential_sharing_group_id = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_app_form_credential_sharing_group_id
  #     form_fill_url_match {
  #         #Required
  #         form_url = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_app_form_fill_url_match_form_url

  #         #Optional
  #         form_url_match_type = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_app_form_fill_url_match_form_url_match_type
  #     }
  #     form_type = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_app_form_type
  #     reveal_password_on_form = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_app_reveal_password_on_form
  #     user_name_form_expression = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_app_user_name_form_expression
  #     user_name_form_template = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_app_user_name_form_template
  # }
  # urnietfparamsscimschemasoracleidcsextensionform_fill_app_template_app_template {

  #     #Optional
  #     configuration = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_template_app_template_configuration
  #     form_cred_method = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_template_app_template_form_cred_method
  #     form_credential_sharing_group_id = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_template_app_template_form_credential_sharing_group_id
  #     form_fill_url_match {
  #         #Required
  #         form_url = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_template_app_template_form_fill_url_match_form_url

  #         #Optional
  #         form_url_match_type = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_template_app_template_form_fill_url_match_form_url_match_type
  #     }
  #     form_type = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_template_app_template_form_type
  #     reveal_password_on_form = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_template_app_template_reveal_password_on_form
  #     sync_from_template = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_template_app_template_sync_from_template
  #     user_name_form_expression = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_template_app_template_user_name_form_expression
  #     user_name_form_template = var.app_urnietfparamsscimschemasoracleidcsextensionform_fill_app_template_app_template_user_name_form_template
  # }
  # urnietfparamsscimschemasoracleidcsextensionkerberos_realm_app {

  #     #Optional
  #     default_encryption_salt_type = var.app_urnietfparamsscimschemasoracleidcsextensionkerberos_realm_app_default_encryption_salt_type
  #     master_key = var.app_urnietfparamsscimschemasoracleidcsextensionkerberos_realm_app_master_key
  #     max_renewable_age = var.app_urnietfparamsscimschemasoracleidcsextensionkerberos_realm_app_max_renewable_age
  #     max_ticket_life = var.app_urnietfparamsscimschemasoracleidcsextensionkerberos_realm_app_max_ticket_life
  #     realm_name = var.app_urnietfparamsscimschemasoracleidcsextensionkerberos_realm_app_realm_name
  #     supported_encryption_salt_types = var.app_urnietfparamsscimschemasoracleidcsextensionkerberos_realm_app_supported_encryption_salt_types
  #     ticket_flags = var.app_urnietfparamsscimschemasoracleidcsextensionkerberos_realm_app_ticket_flags
  # }
  # urnietfparamsscimschemasoracleidcsextensionmanagedapp_app {

  #     #Optional
  #     admin_consent_granted = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_admin_consent_granted
  #     bundle_configuration_properties {
  #         #Required
  #         icf_type = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_configuration_properties_icf_type
  #         name = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_configuration_properties_name
  #         required = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_configuration_properties_required

  #         #Optional
  #         confidential = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_configuration_properties_confidential
  #         display_name = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_configuration_properties_display_name
  #         help_message = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_configuration_properties_help_message
  #         order = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_configuration_properties_order
  #         value = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_configuration_properties_value
  #     }
  #     bundle_pool_configuration {

  #         #Optional
  #         max_idle = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_pool_configuration_max_idle
  #         max_objects = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_pool_configuration_max_objects
  #         max_wait = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_pool_configuration_max_wait
  #         min_evictable_idle_time_millis = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_pool_configuration_min_evictable_idle_time_millis
  #         min_idle = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_bundle_pool_configuration_min_idle
  #     }
  #     connected = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_connected
  #     enable_auth_sync_new_user_notification = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_enable_auth_sync_new_user_notification
  #     enable_sync = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_enable_sync
  #     enable_sync_summary_report_notification = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_enable_sync_summary_report_notification
  #     flat_file_bundle_configuration_properties {
  #         #Required
  #         icf_type = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_flat_file_bundle_configuration_properties_icf_type
  #         name = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_flat_file_bundle_configuration_properties_name
  #         required = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_flat_file_bundle_configuration_properties_required

  #         #Optional
  #         confidential = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_flat_file_bundle_configuration_properties_confidential
  #         display_name = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_flat_file_bundle_configuration_properties_display_name
  #         help_message = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_flat_file_bundle_configuration_properties_help_message
  #         order = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_flat_file_bundle_configuration_properties_order
  #         value = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_flat_file_bundle_configuration_properties_value
  #     }
  #     flat_file_connector_bundle {
  #         #Required
  #         value = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_flat_file_connector_bundle_value

  #         #Optional
  #         display = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_flat_file_connector_bundle_display
  #         well_known_id = oci_identity_domains_well_known.test_well_known.id
  #     }
  #     is_authoritative = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_is_authoritative
  #     three_legged_oauth_credential {

  #         #Optional
  #         access_token = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_three_legged_oauth_credential_access_token
  #         access_token_expiry = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_three_legged_oauth_credential_access_token_expiry
  #         refresh_token = var.app_urnietfparamsscimschemasoracleidcsextensionmanagedapp_app_three_legged_oauth_credential_refresh_token
  #     }
  # }
  # urnietfparamsscimschemasoracleidcsextensionmulticloud_service_app_app {
  #     #Required
  #     multicloud_service_type = var.app_urnietfparamsscimschemasoracleidcsextensionmulticloud_service_app_app_multicloud_service_type

  #     #Optional
  #     multicloud_platform_url = var.app_urnietfparamsscimschemasoracleidcsextensionmulticloud_service_app_app_multicloud_platform_url
  # }
  # urnietfparamsscimschemasoracleidcsextensionopc_service_app {

  #     #Optional
  #     service_instance_identifier = var.app_urnietfparamsscimschemasoracleidcsextensionopc_service_app_service_instance_identifier
  # }
  # urnietfparamsscimschemasoracleidcsextensionradius_app_app {
  #     #Required
  #     client_ip = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_client_ip
  #     include_group_in_response = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_include_group_in_response
  #     port = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_port
  #     secret_key = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_secret_key

  #     #Optional
  #     capture_client_ip = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_capture_client_ip
  #     country_code_response_attribute_id = "1"
  #     end_user_ip_attribute = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_end_user_ip_attribute
  #     group_membership_radius_attribute = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_group_membership_radius_attribute
  #     group_membership_to_return {
  #         #Required
  #         value = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_group_membership_to_return_value
  #     }
  #     group_name_format = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_group_name_format
  #     password_and_otp_together = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_password_and_otp_together
  #     radius_vendor_specific_id = "radiusVendorSpecificId"
  #     response_format = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_response_format
  #     response_format_delimiter = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_response_format_delimiter
  #     type_of_radius_app = var.app_urnietfparamsscimschemasoracleidcsextensionradius_app_app_type_of_radius_app
  # }
  # urnietfparamsscimschemasoracleidcsextensionrequestable_app {

  #     #Optional
  #     requestable = var.app_urnietfparamsscimschemasoracleidcsextensionrequestable_app_requestable
  # }
  # urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app {

  #     #Optional
  #     assertion_consumer_url = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_assertion_consumer_url
  #     encrypt_assertion = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_encrypt_assertion
  #     encryption_algorithm = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_encryption_algorithm
  #     encryption_certificate = "encryptionCertificate"
  #     federation_protocol = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_federation_protocol
  #     group_assertion_attributes {
  #         #Required
  #         name = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_group_assertion_attributes_name

  #         #Optional
  #         condition = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_group_assertion_attributes_condition
  #         format = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_group_assertion_attributes_format
  #         group_name = "groupName"
  #     }
  #     hok_acs_url = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_hok_acs_url
  #     hok_required = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_hok_required
  #     include_signing_cert_in_signature = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_include_signing_cert_in_signature
  #     key_encryption_algorithm = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_key_encryption_algorithm
  #     logout_binding = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_logout_binding
  #     logout_enabled = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_logout_enabled
  #     logout_request_url = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_logout_request_url
  #     logout_response_url = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_logout_response_url
  #     metadata = "metadata"
  #     name_id_format = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_name_id_format
  #     name_id_userstore_attribute = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_name_id_userstore_attribute
  #     partner_provider_id = "partnerProviderId"
  #     partner_provider_pattern = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_partner_provider_pattern
  #     sign_response_or_assertion = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_sign_response_or_assertion
  #     signature_hash_algorithm = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_signature_hash_algorithm
  #     signing_certificate = "signingCertificate"
  #     succinct_id = "succinctId"
  #     user_assertion_attributes {
  #         #Required
  #         name = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_user_assertion_attributes_name
  #         user_store_attribute_name = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_user_assertion_attributes_user_store_attribute_name

  #         #Optional
  #         format = var.app_urnietfparamsscimschemasoracleidcsextensionsaml_service_provider_app_user_assertion_attributes_format
  #     }
  # }
  # urnietfparamsscimschemasoracleidcsextensionweb_tier_policy_app {

  #     #Optional
  #     resource_ref = var.app_urnietfparamsscimschemasoracleidcsextensionweb_tier_policy_app_resource_ref
  #     web_tier_policy_az_control = var.app_urnietfparamsscimschemasoracleidcsextensionweb_tier_policy_app_web_tier_policy_az_control
  #     web_tier_policy_json = var.app_urnietfparamsscimschemasoracleidcsextensionweb_tier_policy_app_web_tier_policy_json
  # }

  # urnietfparamsscimschemasoracleidcsextensionweb_tier_policy_app {
  #     web_tier_policy_json       = "{\"cloudgatePolicy\": {\"version\": \"2.6\",\"requireSecureCookies\": false,\"allowCors\": true,\"disableAuthorize\": false,\"webtierPolicy\": [{\"policyName\": \"default\",\"resourceFilters\": [{\"filter\": \"/onboarding/.*\",\"comment\": \"\",\"type\": \"regex\",\"method\": \"oauth\",\"authorize\": false},{\"filter\": \"/ingestion/.*\",\"comment\": \"\",\"type\": \"regex\",\"method\": \"oauth\",\"authorize\": false},{\"filter\": \"/{{oacinstance}}/.*\",\"comment\": \"\",\"type\": \"regex\",\"method\": \"oauth\",\"authorize\": false},{\"filter\": \"/config/odi/.*\",\"comment\": \"\",\"type\": \"regex\",\"method\": \"oauth\",\"authorize\": false},{\"filter\": \"/platform/.*\",\"comment\": \"\",\"type\": \"regex\",\"method\": \"oauth\",\"authorize\": false},{\"filter\": \"/{{oacinstance}}/xmlpserver/services/?.*\",\"comment\": \"\",\"type\": \"regex\",\"method\": \"public\",\"authorize\": false},{\"filter\": \"/{{oacinstance}}/analytics-ws/?.*\",\"comment\": \"\",\"type\": \"regex\",\"method\": \"public\",\"authorize\": false}]}]}}"
  # }

  # patch the app to deactivate it on destroy, otherwise destroy fails.
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-CMD
      oci identity-domains app patch \
        --endpoint "${self.idcs_endpoint}" \
        --app-id ${self.id} \
        --schemas '["urn:ietf:params:scim:api:messages:2.0:PatchOp"]' \
        --operations '[{"op": "replace", "path": "active", "value": false}]'
    CMD
  }
}

