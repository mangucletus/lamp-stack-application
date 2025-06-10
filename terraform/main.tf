# terraform/main.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create Lightsail instance
resource "aws_lightsail_instance" "blog_server" {
  name              = "blog-server"
  availability_zone = "${var.aws_region}a"
  blueprint_id      = "ubuntu_20_04"
  bundle_id         = "micro_2_0"
  
  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", {
    db_password = var.db_password
  }))

  tags = {
    Environment = "production"
    Project     = "simple-blog"
  }
}

# Create Lightsail static IP
resource "aws_lightsail_static_ip" "blog_server_ip" {
  name = "blog-server-static-ip"
}

# Attach static IP to instance
resource "aws_lightsail_static_ip_attachment" "blog_server_ip_attachment" {
  static_ip_name = aws_lightsail_static_ip.blog_server_ip.name
  instance_name  = aws_lightsail_instance.blog_server.name
}

# Create key pair for SSH access
resource "aws_lightsail_key_pair" "blog_server_key" {
  name = "blog-server-key"
}

# Save private key to local file
resource "local_file" "private_key" {
  content  = aws_lightsail_key_pair.blog_server_key.private_key
  filename = "${path.module}/blog-server-key.pem"
  file_permission = "0400"
}

# Create IAM user for GitHub Actions
resource "aws_iam_user" "github_deploy_user" {
  name = "github-deploy-user"
  path = "/"
}

# Create access key for GitHub Actions user
resource "aws_iam_access_key" "github_deploy_key" {
  user = aws_iam_user.github_deploy_user.name
}

# Create IAM policy for Lightsail access
resource "aws_iam_policy" "lightsail_deploy_policy" {
  name        = "lightsail-deploy-policy"
  description = "Policy for GitHub Actions to deploy to Lightsail"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lightsail:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "github_deploy_attachment" {
  user       = aws_iam_user.github_deploy_user.name
  policy_arn = aws_iam_policy.lightsail_deploy_policy.arn
}