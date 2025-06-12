# terraform/networking.tf - Updated to handle existing resources

# Create VPC only if not using existing resources
resource "aws_vpc" "blog_vpc" {
  count                = var.use_existing_resources ? 0 : 1
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create Internet Gateway only if creating new VPC
resource "aws_internet_gateway" "blog_igw" {
  count  = var.use_existing_resources ? 0 : 1
  vpc_id = aws_vpc.blog_vpc[0].id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create Public Subnet only if not using existing resources
resource "aws_subnet" "blog_public_subnet" {
  count                   = var.use_existing_resources ? 0 : 1
  vpc_id                  = aws_vpc.blog_vpc[0].id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Public"
  }
}

# Create Route Table only if creating new VPC
resource "aws_route_table" "blog_public_rt" {
  count  = var.use_existing_resources ? 0 : 1
  vpc_id = aws_vpc.blog_vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.blog_igw[0].id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associate Route Table with Public Subnet only if creating new resources
resource "aws_route_table_association" "blog_public_rt_association" {
  count          = var.use_existing_resources ? 0 : 1
  subnet_id      = aws_subnet.blog_public_subnet[0].id
  route_table_id = aws_route_table.blog_public_rt[0].id
}