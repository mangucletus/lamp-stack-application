# Define the AWS region to deploy resources in
variable "aws_region" {
  description = "AWS region"      # A short description for documentation
  type        = string            # The type must be a string
  default     = "eu-west-1"       # Default value (Ireland region)
}

# Define the EC2 instance type (hardware configuration)
variable "instance_type" {
  description = "EC2 instance type"   # Explains the purpose of the variable
  type        = string                # The type must be a string
  default     = "t3.micro"            # Cost-effective instance type under free tier
}

# Name of the SSH key pair used to connect to the EC2 instance
variable "key_name" {
  description = "AWS key pair name"   # Short description for the variable
  type        = string                # Must be a string (e.g., "lamp-keypair")
  default     = "lamp-keypair"        # Default value (should match your AWS key pair)
}

# The actual public key content to inject into the instance for SSH access
variable "public_key" {
  description = "Public key for EC2 access"  # What this key is for
  type        = string                       # Public key content as a string
  sensitive   = true                         # Hides value from CLI/UI output for security
}

variable "subnet_id" {
  description = "ID of the subnet where EC2 instance will be launched"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group to attach to EC2 instance"
  type        = string
}