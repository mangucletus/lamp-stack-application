terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "lamp-stack-tfstate-cletusmangu-1749764715"
    key    = "lamp-stack/terraform.tfstate"
    region = "eu-west-1"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Use specific Ubuntu 22.04 LTS AMI for eu-west-1
locals {
  ubuntu_ami_id = "ami-041202be9aa6b3e08"
}

# Create VPC
resource "aws_vpc" "lamp_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "lamp-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "lamp_igw" {
  vpc_id = aws_vpc.lamp_vpc.id

  tags = {
    Name = "lamp-igw"
  }
}

# Create public subnet
resource "aws_subnet" "lamp_public_subnet" {
  vpc_id                  = aws_vpc.lamp_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "lamp-public-subnet"
  }
}

# Create route table
resource "aws_route_table" "lamp_public_rt" {
  vpc_id = aws_vpc.lamp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lamp_igw.id
  }

  tags = {
    Name = "lamp-public-route-table"
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "lamp_public_rta" {
  subnet_id      = aws_subnet.lamp_public_subnet.id
  route_table_id = aws_route_table.lamp_public_rt.id
}

# Create security group
resource "aws_security_group" "lamp_sg" {
  name        = "lamp-security-group"
  description = "Security group for LAMP stack"
  vpc_id      = aws_vpc.lamp_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MySQL access (for local connections)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lamp-security-group"
  }
}

# Create key pair
resource "aws_key_pair" "lamp_keypair" {
  key_name   = var.key_name
  public_key = var.public_key
}

# Create EC2 instance
resource "aws_instance" "lamp_server" {
  ami                    = local.ubuntu_ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.lamp_keypair.key_name
  subnet_id              = aws_subnet.lamp_public_subnet.id
  vpc_security_group_ids = [aws_security_group.lamp_sg.id]
  
  user_data = file("${path.module}/userdata.sh")

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "lamp-server"
  }
}

# Create Elastic IP
resource "aws_eip" "lamp_eip" {
  instance = aws_instance.lamp_server.id
  domain   = "vpc"

  tags = {
    Name = "lamp-eip"
  }
}