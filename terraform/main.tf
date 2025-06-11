/**
 * Main Terraform Configuration for Simple Blog Application
 * 
 * This is the primary Terraform configuration file that:
 * - Configures the Terraform backend (S3 state storage)
 * - Sets up the AWS provider
 * - Creates the S3 bucket for state management
 * - Defines the EC2 instance and related resources
 */

# Terraform Configuration Block
terraform {
  required_version = ">= 1.0" # Minimum Terraform version required

  # Required providers and their versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use AWS provider version 5.x
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0" # For SSH key generation
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0" # For local file operations
    }
  }

  # Backend configuration for storing Terraform state in S3
  # This enables team collaboration and state locking
  backend "s3" {
    bucket = "cletusmangu-lampstack-app-terraform-state-2025" # Change this to your unique bucket name
    key    = "blog-app/terraform.tfstate"
    region = "eu-west-1"

    # Enable state locking using DynamoDB (optional but recommended)
    # dynamodb_table = "terraform-state-locks"

    # Enable encryption for state file
    encrypt = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# Create S3 bucket for Terraform state storage
# This bucket will store the Terraform state file securely
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket

  # Prevent accidental deletion of this bucket
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "Terraform State Bucket"
    Purpose     = "Terraform state storage"
    Environment = var.environment
  }
}

# Enable versioning on the state bucket
# This allows recovery from accidental state corruption
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for the state bucket
# This encrypts the Terraform state file at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access to the state bucket
# This prevents accidental exposure of sensitive state information
resource "aws_s3_bucket_public_access_block" "terraform_state_pab" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create the main EC2 instance for the blog application
resource "aws_instance" "blog_server" {
  # Basic instance configuration
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.blog_keypair.key_name
  subnet_id                   = aws_subnet.blog_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.blog_web_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.blog_ec2_profile.name
  associate_public_ip_address = true

  # Storage configuration
  root_block_device {
    volume_type           = "gp3" # General Purpose SSD v3 (latest generation)
    volume_size           = 20    # 20 GB root volume (sufficient for blog app)
    delete_on_termination = true  # Delete volume when instance is terminated
    encrypted             = true  # Encrypt the root volume for security

    tags = {
      Name = "${var.instance_name}-root-volume"
    }
  }

  # User data script for initial instance setup
  # This script runs automatically when the instance first boots
  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    mysql_root_password = var.mysql_root_password
    mysql_blog_password = var.mysql_blog_password
    github_repo_url     = var.github_repo_url
    project_name        = var.project_name
    environment         = var.environment
  }))

  # Instance tags
  tags = {
    Name        = var.instance_name
    Environment = var.environment
    Project     = var.project_name
    Role        = "WebServer"
    OS          = "Ubuntu"
  }

  # Ensure the instance waits for the VPC and security group to be ready
  depends_on = [
    aws_vpc.blog_vpc,
    aws_security_group.blog_web_sg,
    aws_subnet.blog_public_subnet
  ]
}

# Data source to get the latest Ubuntu 20.04 LTS AMI
# This ensures we always use the most recent Ubuntu image
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu official)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Local values for computed configurations
locals {
  # Common tags for all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  # Computed instance name
  instance_name = "${var.project_name}-${var.environment}-server"
}
