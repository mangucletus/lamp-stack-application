# terraform/security.tf - Updated to handle existing resources

# Create Key Pair only if not using existing one
resource "aws_key_pair" "blog_keypair" {
  count      = var.use_existing_resources && var.existing_key_pair_name != "" ? 0 : 1
  key_name   = var.key_pair_name
  public_key = tls_private_key.blog_private_key[0].public_key_openssh

  tags = {
    Name        = "${var.project_name}-keypair"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Generate private key only if not using existing key pair
resource "tls_private_key" "blog_private_key" {
  count     = var.use_existing_resources && var.existing_key_pair_name != "" ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to local file only if creating new key pair
resource "local_file" "private_key" {
  count           = var.use_existing_resources && var.existing_key_pair_name != "" ? 0 : 1
  content         = tls_private_key.blog_private_key[0].private_key_pem
  filename        = "${var.key_pair_name}.pem"
  file_permission = "0600"
}

# Create Security Group only if not using existing one
resource "aws_security_group" "blog_web_sg" {
  count       = var.use_existing_resources && var.existing_security_group_id != "" ? 0 : 1
  name_prefix = "${var.project_name}-web-sg"
  description = "Security group for blog web server"
  vpc_id      = local.vpc_id

  # Inbound Rules
  ingress {
    description = "HTTP access for web application"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  ingress {
    description = "HTTPS access for secure web application"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  ingress {
    description = "SSH access for server administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Outbound Rules
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-web-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM role for EC2 instance (always create as it's lightweight)
resource "aws_iam_role" "blog_ec2_role" {
  name = "${var.project_name}-ec2-role"

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
resource "aws_iam_instance_profile" "blog_ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.blog_ec2_role.name

  tags = {
    Name        = "${var.project_name}-ec2-profile"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM policy for EC2 instance
resource "aws_iam_role_policy" "blog_ec2_policy" {
  name = "${var.project_name}-ec2-policy"
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