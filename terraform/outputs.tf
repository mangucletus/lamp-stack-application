# terraform/outputs.tf - Updated to handle existing resources

# EC2 Instance Information
output "instance_id" {
  description = "ID of the EC2 instance running the blog application"
  value       = local.instance_id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = local.instance_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance within the VPC"
  value = var.use_existing_resources && var.existing_instance_id != "" ? data.aws_instance.existing_instance[0].private_ip : (local.create_new_instance ? aws_instance.blog_server[0].private_ip : "N/A")
}

output "instance_state" {
  description = "Current state of the EC2 instance"
  value = var.use_existing_resources && var.existing_instance_id != "" ? data.aws_instance.existing_instance[0].instance_state : (local.create_new_instance ? aws_instance.blog_server[0].instance_state : "existing")
}

# Networking Information
output "vpc_id" {
  description = "ID of the VPC hosting the blog infrastructure"
  value       = local.vpc_id
}

output "subnet_id" {
  description = "ID of the public subnet where the EC2 instance is located"
  value       = local.subnet_id
}

output "security_group_id" {
  description = "ID of the security group protecting the EC2 instance"
  value       = local.security_group_id
}

# Access Information
output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i ${local.key_pair_name}.pem ubuntu@${local.instance_ip}"
}

output "website_url" {
  description = "URL to access the blog application"
  value       = "http://${local.instance_ip}/blog"
}

output "server_status_url" {
  description = "URL to check server status"
  value       = "http://${local.instance_ip}"
}

# SSH Key Information
output "ssh_key_name" {
  description = "Name of the SSH key pair for instance access"
  value       = local.key_pair_name
}

output "ssh_private_key_file" {
  description = "Local filename of the SSH private key"
  value       = var.use_existing_resources && var.existing_key_pair_name != "" ? "${var.existing_key_pair_name}.pem" : "${var.key_pair_name}.pem"
  sensitive   = true
}

# Infrastructure Details
output "availability_zone" {
  description = "Availability zone where the instance is running"
  value = var.use_existing_resources && var.existing_instance_id != "" ? data.aws_instance.existing_instance[0].availability_zone : (local.create_new_instance ? aws_instance.blog_server[0].availability_zone : var.availability_zone)
}

output "instance_type" {
  description = "Type of EC2 instance"
  value = var.use_existing_resources && var.existing_instance_id != "" ? data.aws_instance.existing_instance[0].instance_type : var.instance_type
}

# Resource Usage Information
output "using_existing_resources" {
  description = "Whether existing resources are being used"
  value = {
    vpc              = var.use_existing_resources && var.existing_vpc_id != ""
    subnet           = var.use_existing_resources && var.existing_subnet_id != ""
    security_group   = var.use_existing_resources && var.existing_security_group_id != ""
    key_pair         = var.use_existing_resources && var.existing_key_pair_name != ""
    instance         = var.use_existing_resources && var.existing_instance_id != ""
  }
}

# S3 Bucket Information
output "terraform_state_bucket" {
  description = "Name of the S3 bucket storing Terraform state"
  value       = var.terraform_state_bucket
}

# Environment Information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name used for resource naming and tagging"
  value       = var.project_name
}

# Quick Access Summary
output "quick_access_summary" {
  description = "Quick reference for accessing your blog"
  value = {
    blog_url     = "http://${local.instance_ip}/blog"
    ssh_access   = "ssh -i ${local.key_pair_name}.pem ubuntu@${local.instance_ip}"
    status_check = "http://${local.instance_ip}"
    public_ip    = local.instance_ip
    using_existing = var.use_existing_resources
  }
}