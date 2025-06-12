# terraform/outputs.tf - Fresh Infrastructure Outputs

# ==============================================================================
# EC2 INSTANCE OUTPUTS
# ==============================================================================

output "instance_id" {
  description = "ID of the fresh EC2 instance running the blog application"
  value       = aws_instance.blog_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the fresh EC2 instance (Elastic IP)"
  value       = aws_eip.blog_eip.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the fresh EC2 instance within the VPC"
  value       = aws_instance.blog_server.private_ip
}

output "instance_state" {
  description = "Current state of the fresh EC2 instance"
  value       = aws_instance.blog_server.instance_state
}

output "instance_type" {
  description = "Type of the fresh EC2 instance"
  value       = aws_instance.blog_server.instance_type
}

output "instance_ami" {
  description = "AMI ID used for the fresh EC2 instance"
  value       = aws_instance.blog_server.ami
}

output "availability_zone" {
  description = "Availability zone where the fresh instance is running"
  value       = aws_instance.blog_server.availability_zone
}

# ==============================================================================
# NETWORKING OUTPUTS
# ==============================================================================

output "vpc_id" {
  description = "ID of the fresh VPC hosting the blog infrastructure"
  value       = aws_vpc.blog_vpc.id
}

output "vpc_cidr" {
  description = "CIDR block of the fresh VPC"
  value       = aws_vpc.blog_vpc.cidr_block
}

output "subnet_id" {
  description = "ID of the fresh public subnet where the EC2 instance is located"
  value       = aws_subnet.blog_public_subnet.id
}

output "subnet_cidr" {
  description = "CIDR block of the fresh public subnet"
  value       = aws_subnet.blog_public_subnet.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the fresh internet gateway"
  value       = aws_internet_gateway.blog_igw.id
}

output "route_table_id" {
  description = "ID of the fresh public route table"
  value       = aws_route_table.blog_public_rt.id
}

# ==============================================================================
# SECURITY OUTPUTS
# ==============================================================================

output "security_group_id" {
  description = "ID of the fresh security group protecting the EC2 instance"
  value       = aws_security_group.blog_web_sg.id
}

output "security_group_name" {
  description = "Name of the fresh security group"
  value       = aws_security_group.blog_web_sg.name
}

output "ssh_key_name" {
  description = "Name of the fresh SSH key pair for instance access"
  value       = aws_key_pair.blog_keypair.key_name
}

output "ssh_private_key_file" {
  description = "Local filename of the fresh SSH private key"
  value       = "${aws_key_pair.blog_keypair.key_name}.pem"
  sensitive   = true
}

output "ssh_key_fingerprint" {
  description = "Fingerprint of the fresh SSH key pair"
  value       = aws_key_pair.blog_keypair.fingerprint
}

# ==============================================================================
# ELASTIC IP OUTPUTS
# ==============================================================================

output "elastic_ip_id" {
  description = "ID of the fresh Elastic IP address"
  value       = aws_eip.blog_eip.id
}

output "elastic_ip_allocation_id" {
  description = "Allocation ID of the fresh Elastic IP address"
  value       = aws_eip.blog_eip.allocation_id
}

output "elastic_ip_association_id" {
  description = "Association ID of the fresh Elastic IP address"
  value       = aws_eip.blog_eip.association_id
}

output "elastic_ip_domain" {
  description = "Domain of the fresh Elastic IP address"
  value       = aws_eip.blog_eip.domain
}

# ==============================================================================
# IAM OUTPUTS
# ==============================================================================

output "iam_role_name" {
  description = "Name of the fresh IAM role for the EC2 instance"
  value       = aws_iam_role.blog_ec2_role.name
}

output "iam_role_arn" {
  description = "ARN of the fresh IAM role for the EC2 instance"
  value       = aws_iam_role.blog_ec2_role.arn
}

output "iam_instance_profile_name" {
  description = "Name of the fresh IAM instance profile"
  value       = aws_iam_instance_profile.blog_ec2_profile.name
}

output "iam_instance_profile_arn" {
  description = "ARN of the fresh IAM instance profile"
  value       = aws_iam_instance_profile.blog_ec2_profile.arn
}

# ==============================================================================
# ACCESS INFORMATION
# ==============================================================================

output "ssh_command" {
  description = "SSH command to connect to the fresh EC2 instance"
  value       = "ssh -i ${aws_key_pair.blog_keypair.key_name}.pem ubuntu@${aws_eip.blog_eip.public_ip}"
}

output "website_url" {
  description = "URL to access the fresh blog application"
  value       = "http://${aws_eip.blog_eip.public_ip}/blog"
}

output "server_status_url" {
  description = "URL to check fresh server status"
  value       = "http://${aws_eip.blog_eip.public_ip}"
}

output "mysql_connection_command" {
  description = "Command to connect to MySQL database (run from instance)"
  value       = "mysql -u blog_user -p blog_db"
  sensitive   = true
}

# ==============================================================================
# S3 BACKEND OUTPUTS
# ==============================================================================

output "terraform_state_bucket" {
  description = "Name of the S3 bucket storing Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket storing Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "terraform_state_bucket_region" {
  description = "Region of the S3 bucket storing Terraform state"
  value       = aws_s3_bucket.terraform_state.region
}

# ==============================================================================
# DEPLOYMENT INFORMATION
# ==============================================================================

output "deployment_info" {
  description = "Fresh deployment information and metadata"
  value = {
    deployment_type    = "fresh"
    environment       = var.environment
    project_name      = var.project_name
    aws_region        = var.aws_region
    instance_type     = var.instance_type
    deployment_time   = timestamp()
    terraform_version = "~> 1.6"
  }
}

output "resource_tags" {
  description = "Common tags applied to fresh resources"
  value = {
    Environment    = var.environment
    Project        = var.project_name
    ManagedBy      = "Terraform"
    DeploymentType = "Fresh"
  }
}

# ==============================================================================
# COST ESTIMATION
# ==============================================================================

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown for fresh infrastructure (approximate)"
  value = {
    ec2_instance      = "~$8.50/month (t3.micro) or ~$17.00/month (t3.small)"
    ebs_storage       = "~$2.00/month (20GB gp3)"
    elastic_ip        = "~$3.60/month (when attached)"
    data_transfer     = "~$1.00/month (estimated)"
    vpc_components    = "~$0.00/month (no additional charges)"
    total_estimated   = "~$15.10/month (t3.micro) or ~$23.60/month (t3.small)"
    currency          = "USD"
    region            = var.aws_region
    last_updated      = "2024"
  }
}

# ==============================================================================
# MANAGEMENT INFORMATION
# ==============================================================================

output "management_scripts" {
  description = "Available management scripts on the fresh instance"
  value = {
    service_check = "/home/ubuntu/check-services.sh"
    backup_tool   = "/home/ubuntu/backup-blog.sh"
    system_info   = "/home/ubuntu/system-info.txt"
    usage_note    = "SSH to instance and run these scripts for management"
  }
}

output "log_files" {
  description = "Important log files on the fresh instance"
  value = {
    userdata_log     = "/var/log/userdata-setup.log"
    apache_access    = "/var/log/apache2/blog_access.log"
    apache_error     = "/var/log/apache2/blog_error.log"
    mysql_error      = "/var/log/mysql/error.log"
    php_error        = "/var/log/php_errors.log"
    userdata_summary = "/var/log/userdata-summary.txt"
  }
}

output "database_info" {
  description = "Fresh database configuration information"
  value = {
    database_name = "blog_db"
    database_user = "blog_user"
    host          = "localhost"
    port          = 3306
    charset       = "utf8mb4"
    collation     = "utf8mb4_unicode_ci"
    note          = "Password stored in AWS Secrets Manager or environment variables"
  }
  sensitive = true
}

# ==============================================================================
# QUICK ACCESS SUMMARY
# ==============================================================================

output "quick_access_summary" {
  description = "Quick reference for accessing your fresh blog infrastructure"
  value = {
    blog_url         = "http://${aws_eip.blog_eip.public_ip}/blog"
    server_status    = "http://${aws_eip.blog_eip.public_ip}"
    ssh_access       = "ssh -i ${aws_key_pair.blog_keypair.key_name}.pem ubuntu@${aws_eip.blog_eip.public_ip}"
    public_ip        = aws_eip.blog_eip.public_ip
    instance_id      = aws_instance.blog_server.id
    region           = var.aws_region
    environment      = var.environment
    deployment_type  = "fresh"
    key_file         = "${aws_key_pair.blog_keypair.key_name}.pem"
  }
}

# ==============================================================================
# SECURITY INFORMATION
# ==============================================================================

output "security_info" {
  description = "Security configuration of the fresh infrastructure"
  value = {
    ssh_access_from    = var.allowed_ssh_cidrs
    http_access_from   = var.allowed_http_cidrs
    firewall_enabled   = true
    ssl_ready          = true
    security_headers   = true
    encrypted_storage  = true
    iam_role_attached  = true
    vpc_isolated       = true
  }
}

# ==============================================================================
# NEXT STEPS
# ==============================================================================

output "next_steps" {
  description = "Recommended next steps after fresh deployment"
  value = [
    "1. Access your blog at the website_url",
    "2. SSH to the instance and run ~/check-services.sh",
    "3. Customize your blog content and design",
    "4. Set up SSL certificate with Let's Encrypt",
    "5. Configure monitoring and alerting",
    "6. Set up automated backups with ~/backup-blog.sh",
    "7. Review security settings and access controls",
    "8. Consider setting up CloudWatch monitoring",
    "9. Test disaster recovery procedures",
    "10. Document your customizations"
  ]
}