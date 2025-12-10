output "details" {
  value = {
    hostname = oci_redis_redis_cluster.redis.primary_fqdn
    password = random_string.redis_password.result
  }
}