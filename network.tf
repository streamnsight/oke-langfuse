## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  manage_network                  = !var.use_existing_cluster
  use_existing_network            = local.manage_network && var.use_existing_vcn
  create_network                  = local.manage_network && !var.use_existing_vcn
  subnet_cidrs                    = cidrsubnets(var.vcn_cidr, 12, 8, 4, 4, 4) # API + 1 LB + 3 node pools
  created_api_subnet_cidr         = element(local.subnet_cidrs, 0)
  created_lb_subnet_cidr          = element(local.subnet_cidrs, 1)
  created_node_pool_subnets_cidrs = slice(local.subnet_cidrs, 2, 5)
  ADs                             = data.oci_identity_availability_domains.ADs.availability_domains.*.name
}

data "oci_core_vcn" "existing_vcn" {
  #data resource to fetch existing VCN's attributes if used.
  count  = local.use_existing_network ? 1 : 0
  vcn_id = var.vcn_id
}

data "oci_core_subnets" "subnets" {
  count          = local.use_existing_network ? 1 : 0
  compartment_id = data.oci_core_vcn.existing_vcn[0].compartment_id
  vcn_id         = data.oci_core_vcn.existing_vcn[0].id
}

locals {
  existing_subnet_cidrs_map = local.use_existing_network ? { for s in data.oci_core_subnets.subnets[0].subnets[*] : s.id => s.cidr_block } : {}
  api_subnet_cidr           = local.use_existing_network && var.kubernetes_endpoint_subnet != null ? local.existing_subnet_cidrs_map[var.kubernetes_endpoint_subnet] : local.created_api_subnet_cidr
  lb_subnet_cidr            = local.use_existing_network && var.public_lb_subnet != null ? local.existing_subnet_cidrs_map[var.public_lb_subnet] : local.created_lb_subnet_cidr
  node_pool_subnets_cidrs = local.use_existing_network ? [
    for s in [var.np1_subnet, var.np2_subnet, var.np3_subnet] :
    local.existing_subnet_cidrs_map[s]
    if s != null
  ] : local.created_node_pool_subnets_cidrs
}

resource "oci_core_vcn" "oke_vcn" {
  count          = local.create_network ? 1 : 0
  cidr_blocks    = [var.vcn_cidr]
  compartment_id = var.vcn_compartment_id
  dns_label      = "vcn${random_string.deploy_id.result}"
  display_name   = "vcn${random_string.deploy_id.result}"
  defined_tags   = var.vcn_tags
}

resource "oci_core_service_gateway" "oke_sg" {
  count          = local.create_network ? 1 : 0
  compartment_id = var.vcn_compartment_id
  display_name   = "Service Gateway for vcn${random_string.deploy_id.result}"
  vcn_id         = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id
  services {
    service_id = lookup(data.oci_core_services.all_oci_services[0].services[0], "id")
  }
  defined_tags = var.vcn_tags
}

resource "oci_core_nat_gateway" "oke_natgw" {
  count          = local.create_network ? 1 : 0
  compartment_id = var.vcn_compartment_id
  display_name   = "NAT Gateway for vcn${random_string.deploy_id.result}"
  vcn_id         = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id
  defined_tags   = var.vcn_tags
}

resource "oci_core_route_table" "oke_rt_via_natgw_and_sg" {
  count          = local.create_network ? 1 : 0
  compartment_id = var.vcn_compartment_id
  vcn_id         = oci_core_vcn.oke_vcn[0].id
  display_name   = "via NAT & Service Gateway"
  defined_tags   = var.vcn_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.oke_natgw[0].id
  }

  route_rules {
    destination       = lookup(data.oci_core_services.all_oci_services[0].services[0], "cidr_block")
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.oke_sg[0].id
  }
}

resource "oci_core_internet_gateway" "oke_igw" {
  count          = local.create_network ? 1 : 0
  compartment_id = var.vcn_compartment_id
  display_name   = "Internet Gateway for vcn${random_string.deploy_id.result}"
  vcn_id         = oci_core_vcn.oke_vcn[0].id
  defined_tags   = var.vcn_tags
}

resource "oci_core_route_table" "oke_rt_via_igw" {
  count          = local.create_network ? 1 : 0
  compartment_id = var.vcn_compartment_id
  vcn_id         = oci_core_vcn.oke_vcn[0].id
  display_name   = "via Internet Gateway"
  defined_tags   = var.vcn_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.oke_igw[0].id
  }
}

### Security Lists

resource "oci_core_security_list" "oke_api_endpoint_external_sec_list" {
  count          = local.manage_network ? 1 : 0
  compartment_id = var.vcn_compartment_id
  display_name   = "API Endpoint External Comm"
  vcn_id         = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id
  defined_tags   = var.vcn_tags

  # TCP SSL to Services
  egress_security_rules {
    description      = "Allow Kubernetes control plane to communicate with OKE"
    protocol         = "6"
    destination_type = "SERVICE_CIDR_BLOCK"
    destination      = lookup(data.oci_core_services.all_oci_services[0].services[0], "cidr_block")
    stateless        = false

    tcp_options {
      min = 443
      max = 443
    }
  }

  # Incoming from outside to Endpoint 6443
  ingress_security_rules {
    description = "Client access to Kubernetes API endpoint"
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      export OCI_CLI_PROFILE="$${OCI_PROFILE:-DEFAULT}"
      SL_ID="${self.id}"
      VCN_ID="${self.vcn_id}"
      COMPARTMENT_ID="${self.compartment_id}"

      SUBNET_IDS=$(oci network subnet list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --all | jq -r '.data[].id')
      for SUBNET_ID in $SUBNET_IDS; do
        CURRENT=$(oci network subnet get --subnet-id "$SUBNET_ID" | jq '.data."security-list-ids"')
        if ! echo "$CURRENT" | jq -e --arg id "$SL_ID" 'index($id) != null' >/dev/null; then
          continue
        fi
        DESIRED=$(jq -n --argjson cur "$CURRENT" --arg id "$SL_ID" '$cur - [$id]')
        if [ "$(echo "$DESIRED" | jq 'length')" -eq 0 ]; then
          echo "Skipping update for subnet $SUBNET_ID (resulting security-list-ids would be empty)." >&2
          continue
        fi
        oci network subnet update --subnet-id "$SUBNET_ID" --security-list-ids "$DESIRED" --force --wait-for-state AVAILABLE >/dev/null
      done
    EOT
  }
}

resource "oci_core_security_list" "oke_api_endpoint_nodes_sec_list" {
  count          = local.manage_network ? (local.use_existing_network ? length(local.node_pool_subnets_cidrs) : length([for x in [true, var.np2_create_new_subnet, var.np3_create_new_subnet] : x if x])) : 0
  compartment_id = var.vcn_compartment_id
  display_name   = "API Endpoint - Node Pool ${count.index + 1} Comm"
  vcn_id         = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id
  defined_tags   = var.vcn_tags

  # TCP All to Nodes
  egress_security_rules {
    description      = "TCP traffic to worker nodes"
    protocol         = "6" # TCP
    destination_type = "CIDR_BLOCK"
    destination      = local.node_pool_subnets_cidrs[count.index]
    stateless        = false
  }

  # ICMP 3,4 to Nodes
  egress_security_rules {
    description      = "Path Discovery."
    protocol         = "1" # ICMP
    destination_type = "CIDR_BLOCK"
    destination      = local.node_pool_subnets_cidrs[count.index]
    stateless        = false

    icmp_options {
      type = 3
      code = 4
    }
  }

  # Incoming ICMP from Nodes
  ingress_security_rules {
    description = "Path Discovery"
    protocol    = "1" # ICMP
    source      = local.node_pool_subnets_cidrs[count.index]
    stateless   = false

    icmp_options {
      type = 3
      code = 4
    }
  }

  # Incoming TCP 6443 from Nodes
  ingress_security_rules {
    description = "Kubernetes worker to Kubernetes API endpoint communication"
    protocol    = "6" # TCP
    source      = local.node_pool_subnets_cidrs[count.index]
    stateless   = false

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # Incoming TCP 12250 from Nodes
  ingress_security_rules {
    description = "Kubernetes worker to control plane communication"
    protocol    = "6" # TCP
    source      = local.node_pool_subnets_cidrs[count.index]
    stateless   = false

    tcp_options {
      min = 12250
      max = 12250
    }
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      export OCI_CLI_PROFILE="$${OCI_PROFILE:-DEFAULT}"
      SL_ID="${self.id}"
      VCN_ID="${self.vcn_id}"
      COMPARTMENT_ID="${self.compartment_id}"

      SUBNET_IDS=$(oci network subnet list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --all | jq -r '.data[].id')
      for SUBNET_ID in $SUBNET_IDS; do
        CURRENT=$(oci network subnet get --subnet-id "$SUBNET_ID" | jq '.data."security-list-ids"')
        if ! echo "$CURRENT" | jq -e --arg id "$SL_ID" 'index($id) != null' >/dev/null; then
          continue
        fi
        DESIRED=$(jq -n --argjson cur "$CURRENT" --arg id "$SL_ID" '$cur - [$id]')
        if [ "$(echo "$DESIRED" | jq 'length')" -eq 0 ]; then
          echo "Skipping update for subnet $SUBNET_ID (resulting security-list-ids would be empty)." >&2
          continue
        fi
        oci network subnet update --subnet-id "$SUBNET_ID" --security-list-ids "$DESIRED" --force --wait-for-state AVAILABLE >/dev/null
      done
    EOT
  }
}

resource "oci_core_security_list" "oke_nodepool_sec_list" {
  count          = local.manage_network ? 1 : 0
  compartment_id = var.vcn_compartment_id
  display_name   = "Nodepool - Internal Comm"
  vcn_id         = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id
  defined_tags   = var.vcn_tags

  dynamic "egress_security_rules" {
    iterator = cidr
    for_each = local.node_pool_subnets_cidrs
    content {
      description      = "Allow pods on one worker node to communicate with pods on other worker nodes"
      protocol         = "all"
      destination_type = "CIDR_BLOCK"
      destination      = cidr.value
      stateless        = false
    }
  }

  dynamic "ingress_security_rules" {
    iterator = cidr
    for_each = local.node_pool_subnets_cidrs
    content {
      description = "Node to Node"
      protocol    = "all"
      source      = cidr.value
      stateless   = false
    }
  }

  egress_security_rules {
    description      = "Allow nodes to communicate with OKE"
    protocol         = "6"
    destination_type = "SERVICE_CIDR_BLOCK"
    destination      = lookup(data.oci_core_services.all_oci_services[0].services[0], "cidr_block")
    stateless        = false
  }

  egress_security_rules {
    description      = "Kubernetes worker to Kubernetes API endpoint communication"
    protocol         = "6"
    destination_type = "CIDR_BLOCK"
    destination      = local.api_subnet_cidr
    stateless        = false

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  egress_security_rules {
    description      = "Kubernetes worker to control plane communication"
    protocol         = "6"
    destination_type = "CIDR_BLOCK"
    destination      = local.api_subnet_cidr
    stateless        = false

    tcp_options {
      min = 12250
      max = 12250
    }
  }

  ingress_security_rules {
    description = "Allow Kubernetes control plane to communicate with worker nodes"
    protocol    = "6"
    source      = local.api_subnet_cidr
    stateless   = false
  }

  # ICMP out
  egress_security_rules {
    description = "Path Discovery."
    protocol    = 1
    destination = "0.0.0.0/0"
    stateless   = false

    icmp_options {
      type = 3
      code = 4
    }
  }

  # Internet access
  egress_security_rules {
    description      = "Allow worker nodes to communicate with internet"
    protocol         = "6"
    destination_type = "CIDR_BLOCK"
    destination      = "0.0.0.0/0"
    stateless        = false
  }

  # ICMP
  ingress_security_rules {
    description = "Path Discovery"
    protocol    = 1
    source      = "0.0.0.0/0"
    stateless   = false

    icmp_options {
      type = 3
      code = 4
    }
  }

  # SSH
  ingress_security_rules {
    description = "Allow inbound SSH traffic to worker nodes"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  egress_security_rules {
    # iterator = cidr
    # for_each = local.lb_subnets_cidrs
    # content {
    description      = "TCP to LBs"
    protocol         = "6"
    destination_type = "CIDR_BLOCK"
    destination      = local.lb_subnet_cidr
    stateless        = false
    # }
  }

  ingress_security_rules {
    # iterator = cidr
    # for_each = local.lb_subnets_cidrs
    # content {
    description = "TCP from LBs"
    protocol    = "6"
    source      = local.lb_subnet_cidr
    stateless   = false
    # }
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      export OCI_CLI_PROFILE="$${OCI_PROFILE:-DEFAULT}"
      SL_ID="${self.id}"
      VCN_ID="${self.vcn_id}"
      COMPARTMENT_ID="${self.compartment_id}"

      SUBNET_IDS=$(oci network subnet list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --all | jq -r '.data[].id')
      for SUBNET_ID in $SUBNET_IDS; do
        CURRENT=$(oci network subnet get --subnet-id "$SUBNET_ID" | jq '.data."security-list-ids"')
        if ! echo "$CURRENT" | jq -e --arg id "$SL_ID" 'index($id) != null' >/dev/null; then
          continue
        fi
        DESIRED=$(jq -n --argjson cur "$CURRENT" --arg id "$SL_ID" '$cur - [$id]')
        if [ "$(echo "$DESIRED" | jq 'length')" -eq 0 ]; then
          echo "Skipping update for subnet $SUBNET_ID (resulting security-list-ids would be empty)." >&2
          continue
        fi
        oci network subnet update --subnet-id "$SUBNET_ID" --security-list-ids "$DESIRED" --force --wait-for-state AVAILABLE >/dev/null
      done
    EOT
  }
}

resource "oci_core_security_list" "oke_lb_sec_list" {
  count          = local.manage_network ? 1 : 0
  compartment_id = var.vcn_compartment_id
  display_name   = "Internet - Load Balancer Comm"
  vcn_id         = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id
  defined_tags   = var.vcn_tags

  egress_security_rules {
    # iterator = cidr
    # for_each = local.lb_subnets_cidrs
    # content {
    description      = "TCP to LBs"
    protocol         = "6"
    destination_type = "CIDR_BLOCK"
    destination      = "0.0.0.0/0"
    stateless        = false
    # }
  }

  ingress_security_rules {
    description = "TCP to LBs"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false

    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    description = "TCP to LBs"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false

    tcp_options {
      min = 443
      max = 443
    }
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      export OCI_CLI_PROFILE="$${OCI_PROFILE:-DEFAULT}"
      SL_ID="${self.id}"
      VCN_ID="${self.vcn_id}"
      COMPARTMENT_ID="${self.compartment_id}"

      SUBNET_IDS=$(oci network subnet list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --all | jq -r '.data[].id')
      for SUBNET_ID in $SUBNET_IDS; do
        CURRENT=$(oci network subnet get --subnet-id "$SUBNET_ID" | jq '.data."security-list-ids"')
        if ! echo "$CURRENT" | jq -e --arg id "$SL_ID" 'index($id) != null' >/dev/null; then
          continue
        fi
        DESIRED=$(jq -n --argjson cur "$CURRENT" --arg id "$SL_ID" '$cur - [$id]')
        if [ "$(echo "$DESIRED" | jq 'length')" -eq 0 ]; then
          echo "Skipping update for subnet $SUBNET_ID (resulting security-list-ids would be empty)." >&2
          continue
        fi
        oci network subnet update --subnet-id "$SUBNET_ID" --security-list-ids "$DESIRED" --force --wait-for-state AVAILABLE >/dev/null
      done
    EOT
  }
}

resource "oci_core_subnet" "oke_api_endpoint_subnet" {
  count          = local.create_network ? 1 : 0
  cidr_block     = local.api_subnet_cidr
  compartment_id = var.vcn_compartment_id
  vcn_id         = oci_core_vcn.oke_vcn[0].id
  dns_label      = "api"
  display_name   = "API Endpoint Subnet"
  security_list_ids = flatten([
    [oci_core_vcn.oke_vcn[0].default_security_list_id],
    [oci_core_security_list.oke_api_endpoint_external_sec_list[0].id],
    oci_core_security_list.oke_api_endpoint_nodes_sec_list.*.id
  ])
  route_table_id             = var.is_endpoint_public ? oci_core_route_table.oke_rt_via_igw[0].id : oci_core_route_table.oke_rt_via_natgw_and_sg[0].id
  prohibit_public_ip_on_vnic = var.is_endpoint_public ? false : true
  defined_tags               = var.vcn_tags
}

resource "oci_core_subnet" "oke_lb_subnet" {
  count               = local.create_network ? 1 : 0
  cidr_block          = local.lb_subnet_cidr
  compartment_id      = var.vcn_compartment_id
  availability_domain = null
  vcn_id              = oci_core_vcn.oke_vcn[0].id
  dns_label           = "lb"
  display_name        = "Services LBs Subnet"

  security_list_ids = flatten([[oci_core_vcn.oke_vcn[0].default_security_list_id],
  [oci_core_security_list.oke_lb_sec_list[0].id]])
  route_table_id             = oci_core_route_table.oke_rt_via_igw[0].id
  prohibit_public_ip_on_vnic = !var.allow_deploy_public_lb
  defined_tags               = var.vcn_tags
}

resource "oci_core_subnet" "oke_nodepool_subnet" {
  count          = (!local.create_network || var.node_pool_count == 0) ? 0 : length([for x in [true, var.np2_create_new_subnet, var.np3_create_new_subnet] : x if x])
  cidr_block     = local.node_pool_subnets_cidrs[count.index]
  compartment_id = var.vcn_compartment_id
  vcn_id         = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id
  dns_label      = "nodes${count.index + 1}"
  display_name   = "Node Pool ${count.index + 1} Subnet"

  security_list_ids = flatten([
    [oci_core_vcn.oke_vcn[0].default_security_list_id],
    # [oci_core_security_list.oke_nodepool_lb_comm_sec_list[0].id],
    [oci_core_security_list.oke_nodepool_sec_list[0].id],
    # [oci_core_security_list.oke_nodepool_api_comm_sec_list[0].id],
    # [oci_core_security_list.oke_nodepool_internal_sec_list[0].id]
  ])
  route_table_id             = oci_core_route_table.oke_rt_via_natgw_and_sg[0].id
  prohibit_public_ip_on_vnic = true
  defined_tags               = var.vcn_tags
}

# Associations for existing VCNs to ensure security lists are set on existing subnets
locals {
  existing_nodepool_subnet_ids = local.use_existing_network ? compact([var.np1_subnet, var.np2_subnet, var.np3_subnet]) : []
}

/*
resource "null_resource" "detach_api_subnet_sls" {
  count = var.use_existing_vcn ? 1 : 0

  triggers = {
    subnet_id      = var.kubernetes_endpoint_subnet
    oci_profile    = var.oci_profile
    vcn_id         = var.vcn_id
    compartment_id = var.vcn_compartment_id
    remove_names = jsonencode(concat(
      ["API Endpoint External Comm"],
      [for i in range(length(local.node_pool_subnets_cidrs)) : "API Endpoint - Node Pool ${i + 1} Comm"]
    ))
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      export OCI_CLI_PROFILE="${self.triggers.oci_profile}"
      SUBNET_ID="${self.triggers.subnet_id}"
      VCN_ID="${self.triggers.vcn_id}"
      COMPARTMENT_ID="${self.triggers.compartment_id}"
      REMOVE_NAMES='${self.triggers.remove_names}'

      REMOVE_IDS=$(jq -n '[]')
      for name in $(echo "$REMOVE_NAMES" | jq -r '.[]'); do
        id=$(oci network security-list list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --display-name "$name" | jq -r '.data[0].id // empty')
        if [ -n "$id" ]; then
          REMOVE_IDS=$(jq -n --argjson cur "$REMOVE_IDS" --arg id "$id" '$cur + [$id]')
        fi
      done

      if [ "$(echo "$REMOVE_IDS" | jq 'length')" -eq 0 ]; then
        echo "No matching security lists found for subnet $SUBNET_ID; skipping." >&2
        exit 0
      fi

      CURRENT=$(oci network subnet get --subnet-id "$SUBNET_ID" | jq '.data."security-list-ids"')
      DESIRED=$(jq -n --argjson cur "$CURRENT" --argjson rm "$REMOVE_IDS" '$cur - $rm')
      if [ "$(echo "$DESIRED" | jq 'length')" -eq 0 ]; then
        echo "Skipping update for subnet $SUBNET_ID (resulting security-list-ids would be empty)." >&2
        exit 0
      fi
      oci network subnet update --subnet-id "$SUBNET_ID" --security-list-ids "$DESIRED" --force --wait-for-state AVAILABLE >/dev/null
    EOT
  }
}
*/

/*
resource "null_resource" "detach_lb_subnet_sls" {
  count = var.use_existing_vcn ? 1 : 0

  triggers = {
    subnet_id      = var.public_lb_subnet
    oci_profile    = var.oci_profile
    vcn_id         = var.vcn_id
    compartment_id = var.vcn_compartment_id
    remove_names   = jsonencode(["Internet - Load Balancer Comm"])
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      export OCI_CLI_PROFILE="${self.triggers.oci_profile}"
      SUBNET_ID="${self.triggers.subnet_id}"
      VCN_ID="${self.triggers.vcn_id}"
      COMPARTMENT_ID="${self.triggers.compartment_id}"
      REMOVE_NAMES='${self.triggers.remove_names}'

      REMOVE_IDS=$(jq -n '[]')
      for name in $(echo "$REMOVE_NAMES" | jq -r '.[]'); do
        id=$(oci network security-list list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --display-name "$name" | jq -r '.data[0].id // empty')
        if [ -n "$id" ]; then
          REMOVE_IDS=$(jq -n --argjson cur "$REMOVE_IDS" --arg id "$id" '$cur + [$id]')
        fi
      done

      if [ "$(echo "$REMOVE_IDS" | jq 'length')" -eq 0 ]; then
        echo "No matching security lists found for subnet $SUBNET_ID; skipping." >&2
        exit 0
      fi

      CURRENT=$(oci network subnet get --subnet-id "$SUBNET_ID" | jq '.data."security-list-ids"')
      DESIRED=$(jq -n --argjson cur "$CURRENT" --argjson rm "$REMOVE_IDS" '$cur - $rm')
      if [ "$(echo "$DESIRED" | jq 'length')" -eq 0 ]; then
        echo "Skipping update for subnet $SUBNET_ID (resulting security-list-ids would be empty)." >&2
        exit 0
      fi
      oci network subnet update --subnet-id "$SUBNET_ID" --security-list-ids "$DESIRED" --force --wait-for-state AVAILABLE >/dev/null
    EOT
  }
}
*/

/*
resource "null_resource" "detach_nodepool_subnet_sls" {
  for_each = var.use_existing_vcn ? toset(local.existing_nodepool_subnet_ids) : []

  triggers = {
    subnet_id      = each.value
    oci_profile    = var.oci_profile
    vcn_id         = var.vcn_id
    compartment_id = var.vcn_compartment_id
    remove_names   = jsonencode(["Nodepool - Internal Comm"])
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      export OCI_CLI_PROFILE="${self.triggers.oci_profile}"
      SUBNET_ID="${self.triggers.subnet_id}"
      VCN_ID="${self.triggers.vcn_id}"
      COMPARTMENT_ID="${self.triggers.compartment_id}"
      REMOVE_NAMES='${self.triggers.remove_names}'

      REMOVE_IDS=$(jq -n '[]')
      for name in $(echo "$REMOVE_NAMES" | jq -r '.[]'); do
        id=$(oci network security-list list --compartment-id "$COMPARTMENT_ID" --vcn-id "$VCN_ID" --display-name "$name" | jq -r '.data[0].id // empty')
        if [ -n "$id" ]; then
          REMOVE_IDS=$(jq -n --argjson cur "$REMOVE_IDS" --arg id "$id" '$cur + [$id]')
        fi
      done

      if [ "$(echo "$REMOVE_IDS" | jq 'length')" -eq 0 ]; then
        echo "No matching security lists found for subnet $SUBNET_ID; skipping." >&2
        exit 0
      fi

      CURRENT=$(oci network subnet get --subnet-id "$SUBNET_ID" | jq '.data."security-list-ids"')
      DESIRED=$(jq -n --argjson cur "$CURRENT" --argjson rm "$REMOVE_IDS" '$cur - $rm')
      if [ "$(echo "$DESIRED" | jq 'length')" -eq 0 ]; then
        echo "Skipping update for subnet $SUBNET_ID (resulting security-list-ids would be empty)." >&2
        exit 0
      fi
      oci network subnet update --subnet-id "$SUBNET_ID" --security-list-ids "$DESIRED" --force --wait-for-state AVAILABLE >/dev/null
    EOT
  }
}
*/

resource "null_resource" "update_api_subnet_sls" {
  count = local.use_existing_network ? 1 : 0

  triggers = {
    subnet_id = var.kubernetes_endpoint_subnet
    new_ids = jsonencode(concat(
      [oci_core_security_list.oke_api_endpoint_external_sec_list[0].id],
      oci_core_security_list.oke_api_endpoint_nodes_sec_list.*.id
    ))
  }

  depends_on = [
    oci_core_security_list.oke_api_endpoint_external_sec_list,
    oci_core_security_list.oke_api_endpoint_nodes_sec_list
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      export OCI_CLI_PROFILE="${var.oci_profile}"
      SUBNET_ID="${var.kubernetes_endpoint_subnet}"
      CURRENT=$(oci network subnet get --subnet-id "$SUBNET_ID" | jq '.data."security-list-ids"')
      ADD='${jsonencode(concat([oci_core_security_list.oke_api_endpoint_external_sec_list[0].id], oci_core_security_list.oke_api_endpoint_nodes_sec_list.*.id))}'
      DESIRED=$(jq -n --argjson cur "$CURRENT" --argjson add "$ADD" '$cur + $add | unique')
      oci network subnet update --subnet-id "$SUBNET_ID" --security-list-ids "$DESIRED" --force --wait-for-state AVAILABLE >/dev/null
    EOT
  }
}

resource "null_resource" "update_lb_subnet_sls" {
  count = local.use_existing_network ? 1 : 0

  triggers = {
    subnet_id = var.public_lb_subnet
    new_ids   = jsonencode([oci_core_security_list.oke_lb_sec_list[0].id])
  }

  depends_on = [
    oci_core_security_list.oke_lb_sec_list
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      export OCI_CLI_PROFILE="${var.oci_profile}"
      SUBNET_ID="${var.public_lb_subnet}"
      CURRENT=$(oci network subnet get --subnet-id "$SUBNET_ID" | jq '.data."security-list-ids"')
      ADD='${jsonencode([oci_core_security_list.oke_lb_sec_list[0].id])}'
      DESIRED=$(jq -n --argjson cur "$CURRENT" --argjson add "$ADD" '$cur + $add | unique')
      oci network subnet update --subnet-id "$SUBNET_ID" --security-list-ids "$DESIRED" --force --wait-for-state AVAILABLE >/dev/null
    EOT
  }
}

resource "null_resource" "update_nodepool_subnet_sls" {
  for_each = local.use_existing_network ? toset(local.existing_nodepool_subnet_ids) : []

  triggers = {
    subnet_id = each.value
    new_ids = jsonencode([
      oci_core_security_list.oke_nodepool_sec_list[0].id,
    ])
  }

  depends_on = [
    oci_core_security_list.oke_nodepool_sec_list,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command = <<-EOT
      set -euo pipefail
      export OCI_CLI_PROFILE="${var.oci_profile}"
      SUBNET_ID="${each.value}"
      CURRENT=$(oci network subnet get --subnet-id "$SUBNET_ID" | jq '.data."security-list-ids"')
      ADD='${jsonencode([
    oci_core_security_list.oke_nodepool_sec_list[0].id,
])}'
      DESIRED=$(jq -n --argjson cur "$CURRENT" --argjson add "$ADD" '$cur + $add | unique')
      oci network subnet update --subnet-id "$SUBNET_ID" --security-list-ids "$DESIRED" --force --wait-for-state AVAILABLE >/dev/null
    EOT
}
}
