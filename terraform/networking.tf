/**
 * Networking Configuration
 * 
 * This file creates all networking resources required for the EC2 instance:
 * - VPC (Virtual Private Cloud)
 * - Internet Gateway for public internet access
 * - Public subnet for EC2 instance
 * - Route table for internet routing
 * - Elastic IP for static public IP address
 */

# Create VPC - Virtual Private Cloud
# This provides an isolated network environment for our resources
resource "aws_vpc" "blog_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Enable DNS hostnames for instances
  enable_dns_support   = true # Enable DNS resolution

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create Internet Gateway
# This allows our VPC to communicate with the internet
resource "aws_internet_gateway" "blog_igw" {
  vpc_id = aws_vpc.blog_vpc.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create Public Subnet
# This subnet will host our EC2 instance with public internet access
resource "aws_subnet" "blog_public_subnet" {
  vpc_id                  = aws_vpc.blog_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true # Auto-assign public IP to instances

  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Public"
  }
}

# Create Route Table for Public Subnet
# This defines how traffic is routed within the VPC
resource "aws_route_table" "blog_public_rt" {
  vpc_id = aws_vpc.blog_vpc.id

  # Route for internet access via Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.blog_igw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associate Route Table with Public Subnet
# This connects the routing rules to our subnet
resource "aws_route_table_association" "blog_public_rt_association" {
  subnet_id      = aws_subnet.blog_public_subnet.id
  route_table_id = aws_route_table.blog_public_rt.id
}

# Create Elastic IP for static public IP address
# This ensures our server keeps the same IP address even after restarts
resource "aws_eip" "blog_eip" {
  instance = aws_instance.blog_server.id
  domain   = "vpc"

  # Ensure the instance is created before creating the EIP
  depends_on = [aws_instance.blog_server]

  tags = {
    Name        = "${var.project_name}-eip"
    Environment = var.environment
    Project     = var.project_name
  }
}