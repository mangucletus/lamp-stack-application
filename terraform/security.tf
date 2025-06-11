/**
 * Security Configuration
 * 
 * This file creates all security-related resources:
 * - Security groups (firewall rules)
 * - Key pairs for SSH access
 * - IAM roles and policies (if needed for future enhancements)
 */

# Create Key Pair for SSH access
# This generates an SSH key pair for secure instance access
resource "aws_key_pair" "blog_keypair" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.blog_private_key.public_key_openssh

  tags = {
    Name        = "${var.project_name}-keypair"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Generate private key for SSH access
# This creates the actual SSH key pair
resource "tls_private_key" "blog_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096 # Use 4096 bits for better security
}

# Save private key to local file (for development purposes)
# In production, consider using AWS Systems Manager Parameter Store
resource "local_file" "private_key" {
  content  = tls_private_key.blog_private_key.private_key_pem
  filename = "${var.key_pair_name}.pem"

  # Set restrictive file permissions for security
  file_permission = "0600"
}

# Create Security Group for Web Server
# This acts as a virtual firewall controlling inbound and outbound traffic
resource "aws_security_group" "blog_web_sg" {
  name_prefix = "${var.project_name}-web-sg"
  description = "Security group for blog web server"
  vpc_id      = aws_vpc.blog_vpc.id

  # Inbound Rules (Ingress)

  # Allow HTTP traffic (port 80) from specified CIDR blocks
  ingress {
    description = "HTTP access for web application"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # Allow HTTPS traffic (port 443) for future SSL implementation
  ingress {
    description = "HTTPS access for secure web application"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # Allow SSH access (port 22) for server management
  ingress {
    description = "SSH access for server administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Outbound Rules (Egress)

  # Allow all outbound traffic (needed for package installation and updates)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-web-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Optional: Create IAM role for EC2 instance (for future AWS service access)
# This allows the EC2 instance to interact with other AWS services securely
resource "aws_iam_role" "blog_ec2_role" {
  name = "${var.project_name}-ec2-role"

  # Trust policy allowing EC2 to assume this role
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
    Name        = "${var.project_name}-ec2-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create instance profile for the IAM role
# This allows the EC2 instance to use the IAM role
resource "aws_iam_instance_profile" "blog_ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.blog_ec2_role.name

  tags = {
    Name        = "${var.project_name}-ec2-profile"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Optional: Attach policies to the IAM role for specific AWS service access
# Example: CloudWatch logs, S3 access, etc.
resource "aws_iam_role_policy" "blog_ec2_policy" {
  name = "${var.project_name}-ec2-policy"
  role = aws_iam_role.blog_ec2_role.id

  # Policy allowing CloudWatch logs (for application monitoring)
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