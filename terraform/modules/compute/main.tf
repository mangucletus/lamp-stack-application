locals {
  # Static AMI ID for Ubuntu 22.04 LTS in eu-west-1
  ubuntu_ami_id = "ami-0c1c30571d2dae5c9"
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
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  user_data = file("${path.module}/../../userdata.sh") # Bootstrap script

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