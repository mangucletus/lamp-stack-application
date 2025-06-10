# terraform/outputs.tf

output "instance_public_ip" {
  description = "Public IP address of the Lightsail instance"
  value       = aws_lightsail_static_ip.blog_server_ip.ip_address
}

output "instance_name" {
  description = "Name of the Lightsail instance"
  value       = aws_lightsail_instance.blog_server.name
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i blog-server-key.pem ubuntu@${aws_lightsail_static_ip.blog_server_ip.ip_address}"
}

output "website_url" {
  description = "URL to access the blog"
  value       = "http://${aws_lightsail_static_ip.blog_server_ip.ip_address}"
}

output "github_aws_access_key_id" {
  description = "AWS Access Key ID for GitHub Actions"
  value       = aws_iam_access_key.github_deploy_key.id
}

output "github_aws_secret_access_key" {
  description = "AWS Secret Access Key for GitHub Actions"
  value       = aws_iam_access_key.github_deploy_key.secret
  sensitive   = true
}