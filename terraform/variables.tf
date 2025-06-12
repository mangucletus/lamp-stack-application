# terraform/variables.tf - Updated with existing resource options

# Existing Resources Configuration
variable "use_existing_resources" {
  description = "Whether to use existing AWS resources instead of creating new ones"
  type        = bool
  default     = true  # Set to true to use existing resources
}

variable "existing_vpc_id" {
  description = "ID of existing VPC to use (leave empty to create new)"
  type        = string
  default     = ""  # Will be determined from current infrastructure
}

variable "existing_subnet_id" {
  description = "ID of existing subnet to use (leave empty to create new)"
  type        = string
  default     = ""  # Will be determined from current infrastructure
}

variable "existing_security_group_id" {
  description = "ID of existing security group to use (leave empty to create new)"
  type        = string
  default     = ""  # Will be determined from current infrastructure
}

variable "existing_key_pair_name" {
  description = "Name of existing key pair to use (leave empty to create new)"
  type        = string
  default     = ""  # Will be determined from current infrastructure
}

variable "existing_instance_id" {
  description = "ID of existing EC2 instance to use (leave empty to create new)"
  type        = string
  default     = "i-0123456789abcdef0"  # Replace with your actual instance ID
}

# AWS Configuration Variables
variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format like 'eu-west-1'."
  }
}

variable "availability_zone" {
  description = "Availability zone for EC2 instance (should be within the specified region)"
  type        = string
  default     = "eu-west-1a"
}

# EC2 Instance Configuration
variable "instance_type" {
  description = "EC2 instance type (t3.micro recommended for testing, t3.small for production)"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t2.micro", "t2.small"], var.instance_type)
    error_message = "Instance type must be one of: t3.micro, t3.small, t3.medium, t2.micro, t2.small."
  }
}

variable "instance_name" {
  description = "Name tag for the EC2 instance (will appear in AWS console)"
  type        = string
  default     = "simple-blog-server"
}

# AMI Configuration
variable "ami_id" {
  description = "AMI ID for EC2 instance (Ubuntu 20.04 LTS recommended)"
  type        = string
  default     = "ami-0d64bb532e0502c46" # Ubuntu 20.04 LTS in eu-west-1
}

# SSH Key Configuration
variable "key_pair_name" {
  description = "Name for the AWS key pair (used for SSH access)"
  type        = string
  default     = "blog-server-keypair"
}

# Database Configuration
variable "mysql_root_password" {
  description = "Root password for MySQL database"
  type        = string
  default     = "RootSecurePassword123!"
  sensitive   = true
}

variable "mysql_blog_password" {
  description = "Password for blog database user"
  type        = string
  default     = "SecurePassword123!"
  sensitive   = true
}

# Networking Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# S3 Configuration for Terraform State
variable "terraform_state_bucket" {
  description = "S3 bucket name for storing Terraform state (must be globally unique)"
  type        = string
  default     = "cletusmangu-lampstack-app-terraform-state-2025"
}

# Application Configuration
variable "github_repo_url" {
  description = "GitHub repository URL for the blog application"
  type        = string
  default     = "https://github.com/mangucletus/lamp-stack-application.git"
}

# Environment and Tagging
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "simple-blog"
}

# Security Configuration
variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH to the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_http_cidrs" {
  description = "List of CIDR blocks allowed to access HTTP/HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}