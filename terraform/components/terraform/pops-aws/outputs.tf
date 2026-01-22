output "Message" {
  description = "Instructions for configuring your environment after Terraform apply."
  value = join("\n", compact([
    "Next Steps:",
    "1. Test SSH to each EC2 instance's public IP (Only available if private APIServer endpoint is enabled):",
    local.enable_sr && length(data.aws_instances.sr_ec2.public_ips) > 0 ? join("\n", [
      for idx, ip in data.aws_instances.sr_ec2.public_ips :
      "   ssh -i ~/.ssh/${local.key_name} ubuntu@${ip} # ${local.sr_instance_hostname}-${idx + 1}"
    ]) : "   N/A",
    "",
    "Happy deploying <3"
  ]))
}