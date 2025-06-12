terraform {
  required_version = ">= 1.0" # Ensure Terraform version compatibility
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use AWS provider v5.x
    }
  }
  backend "s3" {
    bucket = "lamp-stack-tfstate-cletusmangu-1749764715" # Remote state storage bucket
    key    = "lamp-stack/terraform.tfstate"              # Path to store the state file
    region = "eu-west-1"                                 # Region for the bucket
  }
}

provider "aws" {
  region = var.aws_region # Use variable for region flexibility
}

locals {
  # Static AMI ID for Ubuntu 22.04 LTS in eu-west-1
  ubuntu_ami_id = "ami-0c1c30571d2dae5c9"
}

# Create a VPC for the LAMP stack
resource "aws_vpc" "lamp_vpc" {
  cidr_block           = "10.0.0.0/16"      # Large IP range
  enable_dns_hostnames = true              # Enable DNS for instances
  enable_dns_support   = true              # Required for hostname resolution
  tags = { Name = "lamp-vpc" }
}

# Internet Gateway to allow internet access
resource "aws_internet_gateway" "lamp_igw" {
  vpc_id = aws_vpc.lamp_vpc.id
  tags = { Name = "lamp-igw" }
}

# Public subnet within the VPC
resource "aws_subnet" "lamp_public_subnet" {
  vpc_id                  = aws_vpc.lamp_vpc.id
  cidr_block              = "10.0.1.0/24"               # Smaller subnet from VPC range
  availability_zone       = "${var.aws_region}a"       # Specific AZ for availability
  map_public_ip_on_launch = true                        # Auto-assign public IP
  tags = { Name = "lamp-public-subnet" }
}

# Public route table to direct traffic to internet
resource "aws_route_table" "lamp_public_rt" {
  vpc_id = aws_vpc.lamp_vpc.id
  route {
    cidr_block = "0.0.0.0/0"                  # Default route
    gateway_id = aws_internet_gateway.lamp_igw.id
  }
  tags = { Name = "lamp-public-route-table" }
}

# Associate route table with the public subnet
resource "aws_route_table_association" "lamp_public_rta" {
  subnet_id      = aws_subnet.lamp_public_subnet.id
  route_table_id = aws_route_table.lamp_public_rt.id
}

# Security Group to allow traffic
resource "aws_security_group" "lamp_sg" {
  name        = "lamp-security-group"
  description = "Security group for LAMP stack"
  vpc_id      = aws_vpc.lamp_vpc.id

  # Allow SSH from anywhere (use a limited CIDR in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow MySQL within the VPC (internal use only)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lamp-security-group" }
}

# Create Key Pair for EC2 SSH Access
resource "aws_key_pair" "lamp_keypair" {
  key_name   = var.key_name     # e.g., "lamp-keypair"
  public_key = var.public_key   # Loaded from a Terraform variable
}

# Launch EC2 instance
resource "aws_instance" "lamp_server" {
  ami                    = local.ubuntu_ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.lamp_keypair.key_name
  subnet_id              = aws_subnet.lamp_public_subnet.id
  vpc_security_group_ids = [aws_security_group.lamp_sg.id]

  user_data = file("${path.module}/userdata.sh") # Bootstrap script

  root_block_device {
    volume_type = "gp3"  # Latest generation of SSD volumes
    volume_size = 20     # 20 GB root volume
    encrypted   = true   # Encrypt root volume for security
  }

  tags = { Name = "lamp-server" }
}

# Assign Elastic IP to EC2 instance
resource "aws_eip" "lamp_eip" {
  instance = aws_instance.lamp_server.id
  domain   = "vpc"
  tags = { Name = "lamp-eip" }
}

