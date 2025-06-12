# terraform/main.tf - Updated to handle existing resources

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket = "cletusmangu-lampstack-app-terraform-state-2025"
    key    = "blog-app/terraform.tfstate"
    region = "eu-west-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources to check for existing resources
data "aws_s3_bucket" "existing_state_bucket" {
  bucket = var.terraform_state_bucket
  count  = var.use_existing_resources ? 1 : 0
}

data "aws_vpc" "existing_vpc" {
  count = var.use_existing_resources && var.existing_vpc_id != "" ? 1 : 0
  id    = var.existing_vpc_id
}

data "aws_subnet" "existing_subnet" {
  count = var.use_existing_resources && var.existing_subnet_id != "" ? 1 : 0
  id    = var.existing_subnet_id
}

data "aws_security_group" "existing_sg" {
  count = var.use_existing_resources && var.existing_security_group_id != "" ? 1 : 0
  id    = var.existing_security_group_id
}

data "aws_key_pair" "existing_keypair" {
  count    = var.use_existing_resources && var.existing_key_pair_name != "" ? 1 : 0
  key_name = var.existing_key_pair_name
}

data "aws_instance" "existing_instance" {
  count = var.use_existing_resources && var.existing_instance_id != "" ? 1 : 0
  instance_id = var.existing_instance_id
}

# Create S3 bucket only if it doesn't exist
resource "aws_s3_bucket" "terraform_state" {
  count  = var.use_existing_resources ? 0 : 1
  bucket = var.terraform_state_bucket

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "Terraform State Bucket"
    Purpose     = "Terraform state storage"
    Environment = var.environment
  }
}

# S3 bucket versioning (conditional)
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  count  = var.use_existing_resources ? 0 : 1
  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption (conditional)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  count  = var.use_existing_resources ? 0 : 1
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block (conditional)
resource "aws_s3_bucket_public_access_block" "terraform_state_pab" {
  count  = var.use_existing_resources ? 0 : 1
  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Local values for resource selection
locals {
  # Use existing resources if specified, otherwise create new ones
  vpc_id = var.use_existing_resources && var.existing_vpc_id != "" ? data.aws_vpc.existing_vpc[0].id : aws_vpc.blog_vpc[0].id
  
  subnet_id = var.use_existing_resources && var.existing_subnet_id != "" ? data.aws_subnet.existing_subnet[0].id : aws_subnet.blog_public_subnet[0].id
  
  security_group_id = var.use_existing_resources && var.existing_security_group_id != "" ? data.aws_security_group.existing_sg[0].id : aws_security_group.blog_web_sg[0].id
  
  key_pair_name = var.use_existing_resources && var.existing_key_pair_name != "" ? data.aws_key_pair.existing_keypair[0].key_name : aws_key_pair.blog_keypair[0].key_name
  
  # Check if we should create a new instance or use existing
  create_new_instance = var.use_existing_resources && var.existing_instance_id != "" ? false : true
  
  instance_id = var.use_existing_resources && var.existing_instance_id != "" ? data.aws_instance.existing_instance[0].id : (local.create_new_instance ? aws_instance.blog_server[0].id : "")
  
  instance_ip = var.use_existing_resources && var.existing_instance_id != "" ? data.aws_instance.existing_instance[0].public_ip : (local.create_new_instance ? aws_eip.blog_eip[0].public_ip : "")
}

# EC2 Instance (conditional creation)
resource "aws_instance" "blog_server" {
  count = local.create_new_instance ? 1 : 0
  
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = local.key_pair_name
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [local.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.blog_ec2_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.instance_name}-root-volume"
    }
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    mysql_root_password = var.mysql_root_password
    mysql_blog_password = var.mysql_blog_password
    github_repo_url     = var.github_repo_url
    project_name        = var.project_name
    environment         = var.environment
  }))

  tags = {
    Name        = var.instance_name
    Environment = var.environment
    Project     = var.project_name
    Role        = "WebServer"
    OS          = "Ubuntu"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP (conditional creation)
resource "aws_eip" "blog_eip" {
  count    = local.create_new_instance ? 1 : 0
  instance = aws_instance.blog_server[0].id
  domain   = "vpc"

  depends_on = [aws_instance.blog_server]

  tags = {
    Name        = "${var.project_name}-eip"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}