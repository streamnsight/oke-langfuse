output "content" {
  value = {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.sh", {
      docker_login_script = base64encode(file("${path.module}/scripts/docker_login.sh"))
      docker_credential_helper_script = base64encode(file("${path.module}/scripts/docker-credential-helper-init.sh"))
    }))
    # docker_login_script = base64encode(file("${path.module}/scripts/docker_login.sh"))
    # docker_credential_helper_script = base64encode(file("${path.module}/scripts/docker-credential-helper-init.sh"))
    # cron_job_script = base64encode(file("${path.module}/scripts/cron_job.sh"))
  }
}