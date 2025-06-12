variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "AWS key pair name"
  type        = string
  default     = "lamp-keypair"
}

variable "public_key" {
  description = "Public key for EC2 access"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
  default     = "SecurePass123!"
}