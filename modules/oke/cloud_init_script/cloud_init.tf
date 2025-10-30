output "content" {
  value = base64encode(templatefile("${path.module}/cloud-init.tmpl.yaml", {
    base64_encoded_docker_login_script            = base64encode(file("${path.module}/scripts/docker_login.sh"))
    base64_encoded_docker_cred_init_helper_script = base64encode(file("${path.module}/scripts/docker-credential-helper-init.sh"))
  }))
}