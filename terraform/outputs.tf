/**
 * Terraform Outputs Configuration
 * 
 * This file defines the output values that will be displayed after Terraform
 * successfully creates the infrastructure. These outputs provide important
 * information needed to access and manage the deployed resources.
 */

# EC2 Instance Information
output "instance_id" {
  description = "ID of the EC2 instance running the blog application"
  value       = aws_instance.blog_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance (Elastic IP)"
  value       = aws_eip.blog_eip.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance within the VPC"
  value       = aws_instance.blog_server.private_ip
}

output "instance_state" {
  description = "Current state of the EC2 instance"
  value       = aws_instance.blog_server.instance_state
}

# Networking Information
output "vpc_id" {
  description = "ID of the VPC hosting the blog infrastructure"
  value       = aws_vpc.blog_vpc.id
}

output "subnet_id" {
  description = "ID of the public subnet where the EC2 instance is located"
  value       = aws_subnet.blog_public_subnet.id
}

output "security_group_id" {
  description = "ID of the security group protecting the EC2 instance"
  value       = aws_security_group.blog_web_sg.id
}

# Access Information
output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i ${aws_key_pair.blog_keypair.key_name}.pem ubuntu@${aws_eip.blog_eip.public_ip}"
}

output "website_url" {
  description = "URL to access the blog application"
  value       = "http://${aws_eip.blog_eip.public_ip}/blog"
}

output "server_status_url" {
  description = "URL to check server status (before blog deployment)"
  value       = "http://${aws_eip.blog_eip.public_ip}"
}

# SSH Key Information
output "ssh_key_name" {
  description = "Name of the SSH key pair for instance access"
  value       = aws_key_pair.blog_keypair.key_name
}

output "ssh_private_key_file" {
  description = "Local filename of the SSH private key"
  value       = "${aws_key_pair.blog_keypair.key_name}.pem"
  sensitive   = true
}

# Infrastructure Details
output "availability_zone" {
  description = "Availability zone where the instance is running"
  value       = aws_instance.blog_server.availability_zone
}

output "instance_type" {
  description = "Type of EC2 instance (e.g., t3.micro)"
  value       = aws_instance.blog_server.instance_type
}

# Storage Information
output "root_volume_id" {
  description = "ID of the root EBS volume"
  value       = aws_instance.blog_server.root_block_device[0].volume_id
}

# Elastic IP Information
output "elastic_ip_id" {
  description = "ID of the Elastic IP address"
  value       = aws_eip.blog_eip.id
}

output "elastic_ip_allocation_id" {
  description = "Allocation ID of the Elastic IP address"
  value       = aws_eip.blog_eip.allocation_id
}

# S3 Bucket Information
output "terraform_state_bucket" {
  description = "Name of the S3 bucket storing Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

# Cost Estimation Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (approximate)"
  value = {
    ec2_instance    = "~$8.50/month (t3.micro)"
    ebs_storage     = "~$2.00/month (20GB gp3)"
    elastic_ip      = "~$3.60/month (when attached)"
    data_transfer   = "~$0.50/month (estimated)"
    total_estimated = "~$14.60/month"
  }
}

# Environment Information
output "environment" {
  description = "Environment name (dev, staging, production)"
  value       = var.environment
}

output "project_name" {
  description = "Project name used for resource naming and tagging"
  value       = var.project_name
}

# Resource ARNs (for future integrations)
output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.blog_server.arn
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.blog_vpc.arn
}

# Quick Access Summary
output "quick_access_summary" {
  description = "Quick reference for accessing your blog"
  value = {
    blog_url     = "http://${aws_eip.blog_eip.public_ip}/blog"
    ssh_access   = "ssh -i ${aws_key_pair.blog_keypair.key_name}.pem ubuntu@${aws_eip.blog_eip.public_ip}"
    status_check = "http://${aws_eip.blog_eip.public_ip}"
    public_ip    = aws_eip.blog_eip.public_ip
  }
}