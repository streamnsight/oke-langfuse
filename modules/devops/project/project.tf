resource "oci_devops_project" "project" {
  compartment_id = var.compartment_id
  description    = var.project_name
  freeform_tags = {
  }
  name = replace(lower(var.project_name), " ", "_")
  notification_config {
    topic_id = oci_ons_notification_topic.topic.id
  }
  defined_tags = var.defined_tags

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_logging_log_group" "log_group" {
  compartment_id = var.compartment_id
  description    = "${var.project_name} Log Group"
  display_name   = substr("${replace(lower(var.project_name), " ", "_")}_log_group", 0, 256)
  defined_tags   = var.defined_tags

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_logging_log" "log" {
  configuration {
    compartment_id = var.compartment_id
    source {
      category    = "all"
      resource    = oci_devops_project.project.id
      service     = "devops"
      source_type = "OCISERVICE"
    }
  }
  display_name       = "${replace(lower(var.project_name), " ", "_")}_log"
  defined_tags       = var.defined_tags
  is_enabled         = "true"
  log_group_id       = oci_logging_log_group.log_group.id
  log_type           = "SERVICE"
  retention_duration = "30"

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_ons_notification_topic" "topic" {
  compartment_id = var.compartment_id
  description    = "${var.project_name} Notification Topic"
  defined_tags   = var.defined_tags
  name           = "${replace(lower(var.project_name), " ", "_")}_topic"

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

