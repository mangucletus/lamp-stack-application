# terraform/main.tf - Fresh deployment configuration

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
      DeploymentType = "Fresh"
      CreatedAt   = timestamp()
    }
  }
}

# Create S3 bucket for Terraform state storage (if it doesn't exist)
resource "aws_s3_bucket" "terraform_state" {
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

# Enable versioning on the state bucket
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for the state bucket
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
resource "aws_s3_bucket_public_access_block" "terraform_state_pab" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create VPC for fresh deployment
resource "aws_vpc" "blog_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc-fresh"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "blog_igw" {
  vpc_id = aws_vpc.blog_vpc.id

  tags = {
    Name        = "${var.project_name}-igw-fresh"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create Public Subnet
resource "aws_subnet" "blog_public_subnet" {
  vpc_id                  = aws_vpc.blog_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-fresh"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Public"
  }
}

# Create Route Table for Public Subnet
resource "aws_route_table" "blog_public_rt" {
  vpc_id = aws_vpc.blog_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.blog_igw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt-fresh"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associate Route Table with Public Subnet
resource "aws_route_table_association" "blog_public_rt_association" {
  subnet_id      = aws_subnet.blog_public_subnet.id
  route_table_id = aws_route_table.blog_public_rt.id
}

# Generate fresh SSH key pair
resource "tls_private_key" "blog_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create fresh AWS key pair
resource "aws_key_pair" "blog_keypair" {
  key_name   = "${var.project_name}-keypair-${random_id.key_suffix.hex}"
  public_key = tls_private_key.blog_private_key.public_key_openssh

  tags = {
    Name        = "${var.project_name}-keypair-fresh"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Random suffix for unique resource names
resource "random_id" "key_suffix" {
  byte_length = 4
}

# Save private key to local file
resource "local_file" "private_key" {
  content         = tls_private_key.blog_private_key.private_key_pem
  filename        = "${aws_key_pair.blog_keypair.key_name}.pem"
  file_permission = "0600"
}

# Create fresh Security Group
resource "aws_security_group" "blog_web_sg" {
  name_prefix = "${var.project_name}-web-sg-fresh-"
  description = "Fresh security group for blog web server"
  vpc_id      = aws_vpc.blog_vpc.id

  # HTTP access
  ingress {
    description = "HTTP access for web application"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # HTTPS access
  ingress {
    description = "HTTPS access for secure web application"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # SSH access
  ingress {
    description = "SSH access for server administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-web-sg-fresh"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM role for EC2 instance
resource "aws_iam_role" "blog_ec2_role" {
  name = "${var.project_name}-ec2-role-${random_id.key_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-role-fresh"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create instance profile for the IAM role
resource "aws_iam_instance_profile" "blog_ec2_profile" {
  name = "${var.project_name}-ec2-profile-${random_id.key_suffix.hex}"
  role = aws_iam_role.blog_ec2_role.name

  tags = {
    Name        = "${var.project_name}-ec2-profile-fresh"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM policy for EC2 instance
resource "aws_iam_role_policy" "blog_ec2_policy" {
  name = "${var.project_name}-ec2-policy-${random_id.key_suffix.hex}"
  role = aws_iam_role.blog_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create fresh EC2 instance
resource "aws_instance" "blog_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.blog_keypair.key_name
  subnet_id                   = aws_subnet.blog_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.blog_web_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.blog_ec2_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.instance_name}-fresh-root-volume"
    }
  }

  # Fresh userdata script for complete setup
  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    mysql_root_password = var.mysql_root_password
    mysql_blog_password = var.mysql_blog_password
    github_repo_url     = var.github_repo_url
    project_name        = var.project_name
    environment         = var.environment
  }))

  tags = {
    Name        = "${var.instance_name}-fresh"
    Environment = var.environment
    Project     = var.project_name
    Role        = "WebServer"
    OS          = "Ubuntu"
    Deployment  = "Fresh"
  }

  # Ensure proper resource ordering
  depends_on = [
    aws_vpc.blog_vpc,
    aws_subnet.blog_public_subnet,
    aws_security_group.blog_web_sg,
    aws_internet_gateway.blog_igw,
    aws_route_table_association.blog_public_rt_association
  ]
}

# Create Elastic IP for fresh instance
resource "aws_eip" "blog_eip" {
  instance = aws_instance.blog_server.id
  domain   = "vpc"

  depends_on = [aws_instance.blog_server, aws_internet_gateway.blog_igw]

  tags = {
    Name        = "${var.project_name}-eip-fresh"
    Environment = var.environment
    Project     = var.project_name
  }
}