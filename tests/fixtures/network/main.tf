resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}

data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

locals {
  name_prefix                 = "${var.name_prefix}-${random_string.suffix.result}"
  subnet_cidrs                = cidrsubnets(var.vcn_cidr, 12, 8, 4, 4, 4)
  api_subnet_cidr             = local.subnet_cidrs[0]
  lb_subnet_cidr              = local.subnet_cidrs[1]
  node_pool_subnets_cidrs     = slice(local.subnet_cidrs, 2, 5)
  node_pool_subnet_dns_labels = ["nodes1", "nodes2", "nodes3"]
}

resource "oci_core_vcn" "shared" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${local.name_prefix}-vcn"
  dns_label      = "v${random_string.suffix.result}"
  defined_tags   = var.defined_tags
}

resource "oci_core_internet_gateway" "internet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  display_name   = "${local.name_prefix}-igw"
  defined_tags   = var.defined_tags
}

resource "oci_core_nat_gateway" "nat" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  display_name   = "${local.name_prefix}-nat"
  defined_tags   = var.defined_tags
}

resource "oci_core_service_gateway" "service" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  display_name   = "${local.name_prefix}-sgw"
  defined_tags   = var.defined_tags

  services {
    service_id = data.oci_core_services.all_oci_services.services[0].id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  display_name   = "${local.name_prefix}-private-rt"
  defined_tags   = var.defined_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat.id
  }

  route_rules {
    destination       = data.oci_core_services.all_oci_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.service.id
  }
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  display_name   = "${local.name_prefix}-public-rt"
  defined_tags   = var.defined_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.internet.id
  }
}

resource "oci_core_security_list" "api_external" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  display_name   = "${local.name_prefix}-api-external"
  defined_tags   = var.defined_tags

  egress_security_rules {
    description      = "Allow Kubernetes control plane to communicate with OKE services"
    protocol         = "6"
    destination_type = "SERVICE_CIDR_BLOCK"
    destination      = data.oci_core_services.all_oci_services.services[0].cidr_block

    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    description = "Client access to Kubernetes API endpoint"
    protocol    = "6"
    source      = "0.0.0.0/0"

    tcp_options {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_security_list" "api_nodes" {
  for_each       = { for index, cidr in local.node_pool_subnets_cidrs : index => cidr }
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  display_name   = "${local.name_prefix}-api-nodes-${each.key + 1}"
  defined_tags   = var.defined_tags

  egress_security_rules {
    description      = "TCP traffic to worker nodes"
    protocol         = "6"
    destination_type = "CIDR_BLOCK"
    destination      = each.value
  }

  egress_security_rules {
    description      = "Path discovery"
    protocol         = "1"
    destination_type = "CIDR_BLOCK"
    destination      = each.value

    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    description = "Path discovery"
    protocol    = "1"
    source      = each.value

    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    description = "Worker to API communication"
    protocol    = "6"
    source      = each.value

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    description = "Worker to control plane communication"
    protocol    = "6"
    source      = each.value

    tcp_options {
      min = 12250
      max = 12250
    }
  }
}

resource "oci_core_security_list" "nodepool" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  display_name   = "${local.name_prefix}-nodepool"
  defined_tags   = var.defined_tags

  dynamic "egress_security_rules" {
    for_each = local.node_pool_subnets_cidrs
    content {
      description      = "Allow pod-to-pod communication across node pool subnets"
      protocol         = "all"
      destination_type = "CIDR_BLOCK"
      destination      = egress_security_rules.value
    }
  }

  dynamic "ingress_security_rules" {
    for_each = local.node_pool_subnets_cidrs
    content {
      description = "Node to node communication"
      protocol    = "all"
      source      = ingress_security_rules.value
    }
  }

  egress_security_rules {
    description      = "Allow nodes to communicate with OKE services"
    protocol         = "6"
    destination_type = "SERVICE_CIDR_BLOCK"
    destination      = data.oci_core_services.all_oci_services.services[0].cidr_block
  }

  egress_security_rules {
    description      = "Worker to API communication"
    protocol         = "6"
    destination_type = "CIDR_BLOCK"
    destination      = local.api_subnet_cidr

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  egress_security_rules {
    description      = "Worker to control plane communication"
    protocol         = "6"
    destination_type = "CIDR_BLOCK"
    destination      = local.api_subnet_cidr

    tcp_options {
      min = 12250
      max = 12250
    }
  }

  ingress_security_rules {
    description = "Allow control plane to communicate with worker nodes"
    protocol    = "6"
    source      = local.api_subnet_cidr
  }

  egress_security_rules {
    description = "Path discovery"
    protocol    = "1"
    destination = "0.0.0.0/0"

    icmp_options {
      type = 3
      code = 4
    }
  }

  egress_security_rules {
    description      = "Allow worker nodes to communicate with internet"
    protocol         = "6"
    destination_type = "CIDR_BLOCK"
    destination      = "0.0.0.0/0"
  }

  ingress_security_rules {
    description = "Path discovery"
    protocol    = "1"
    source      = "0.0.0.0/0"

    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    description = "Allow inbound SSH traffic to worker nodes"
    protocol    = "6"
    source      = "0.0.0.0/0"

    tcp_options {
      min = 22
      max = 22
    }
  }

  egress_security_rules {
    description      = "TCP to load balancers"
    protocol         = "6"
    destination_type = "CIDR_BLOCK"
    destination      = local.lb_subnet_cidr
  }

  ingress_security_rules {
    description = "TCP from load balancers"
    protocol    = "6"
    source      = local.lb_subnet_cidr
  }
}

resource "oci_core_security_list" "lb" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  display_name   = "${local.name_prefix}-lb"
  defined_tags   = var.defined_tags

  egress_security_rules {
    description      = "Outbound traffic from load balancers"
    protocol         = "6"
    destination_type = "CIDR_BLOCK"
    destination      = "0.0.0.0/0"
  }

  ingress_security_rules {
    description = "HTTP to load balancers"
    protocol    = "6"
    source      = "0.0.0.0/0"

    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    description = "HTTPS to load balancers"
    protocol    = "6"
    source      = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_subnet" "api" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  cidr_block     = local.api_subnet_cidr
  display_name   = "${local.name_prefix}-api"
  dns_label      = "api"
  defined_tags   = var.defined_tags

  route_table_id             = var.allow_public_api_endpoint ? oci_core_route_table.public.id : oci_core_route_table.private.id
  prohibit_public_ip_on_vnic = !var.allow_public_api_endpoint
  security_list_ids = concat(
    [oci_core_vcn.shared.default_security_list_id, oci_core_security_list.api_external.id],
    [for security_list in values(oci_core_security_list.api_nodes) : security_list.id]
  )
}

resource "oci_core_subnet" "lb" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  cidr_block     = local.lb_subnet_cidr
  display_name   = "${local.name_prefix}-lb"
  dns_label      = "lb"
  defined_tags   = var.defined_tags

  route_table_id             = oci_core_route_table.public.id
  prohibit_public_ip_on_vnic = !var.allow_public_lb
  security_list_ids          = [oci_core_vcn.shared.default_security_list_id, oci_core_security_list.lb.id]
}

resource "oci_core_subnet" "nodepool" {
  for_each       = { for index, cidr in local.node_pool_subnets_cidrs : index => cidr }
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.shared.id
  cidr_block     = each.value
  display_name   = "${local.name_prefix}-nodepool-${each.key + 1}"
  dns_label      = local.node_pool_subnet_dns_labels[tonumber(each.key)]
  defined_tags   = var.defined_tags

  route_table_id             = oci_core_route_table.private.id
  prohibit_public_ip_on_vnic = true
  security_list_ids          = [oci_core_vcn.shared.default_security_list_id, oci_core_security_list.nodepool.id]
}
