mock_provider "oci" {
  mock_data "oci_containerengine_node_pool_option" {
    defaults = {
      sources = [
        {
          image_id    = "ol9-oke"
          source_name = "Oracle-Linux-9.8-2026.08.14-0-OKE-1.37.0-1820"
          source_type = "IMAGE"
        },
        {
          image_id    = "ol8-base"
          source_name = "Oracle-Linux-8.10-2026.08.14-0"
          source_type = "IMAGE"
        },
        {
          image_id    = "ol8-oke"
          source_name = "Oracle-Linux-8.10-2026.08.14-0-OKE-1.37.0-1820"
          source_type = "IMAGE"
        }
      ]
    }
  }

  mock_data "oci_core_image" {
    defaults = {
      display_name = "mock-oke-image"
      time_created = "2026-09-21T23:31:29Z"
    }
  }
}

variables {
  compartment_id           = "unused-by-selector"
  kubernetes_version       = "v1.37.0"
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.E5.Flex"
}

run "ol9_without_platform_image" {
  command = plan

  assert {
    condition     = output.selected_image_id == "ol9-oke" && output.selector.base_image_id == null
    error_message = "An OKE image must be selectable without a separate platform image entry."
  }
}

run "ol8_with_platform_image" {
  command = plan

  variables {
    operating_system_version = "8"
  }

  assert {
    condition     = output.selected_image_id == "ol8-oke" && output.selector.base_image_id == "ol8-base"
    error_message = "OL8 selection must preserve optional platform image diagnostics."
  }
}

run "missing_kubernetes_version" {
  command = plan

  variables {
    kubernetes_version = "v1.99.0"
  }

  expect_failures = [terraform_data.selector_guard]
}

run "explicit_override" {
  command = plan

  variables {
    image_id_override = "custom-image"
  }

  assert {
    condition     = output.selected_image_id == "custom-image" && output.selector.base_image_id == null
    error_message = "An explicit image override must continue to bypass automatic selection."
  }
}
