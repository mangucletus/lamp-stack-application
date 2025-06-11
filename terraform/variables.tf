/**
 * Terraform Variables Configuration
 * 
 * This file defines all the input variables used throughout the Terraform configuration.
 * Variables make the infrastructure code reusable and configurable for different environments.
 */

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
  default     = ["0.0.0.0/0"] # Change this to your IP for better security
}

variable "allowed_http_cidrs" {
  description = "List of CIDR blocks allowed to access HTTP/HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Allow public access to web application
}