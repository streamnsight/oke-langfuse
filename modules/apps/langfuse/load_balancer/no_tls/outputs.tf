

output "ip_address" {
  value = data.oci_load_balancer_load_balancers.load_balancers.load_balancers[0].ip_addresses[0]
}