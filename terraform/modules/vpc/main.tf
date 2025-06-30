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