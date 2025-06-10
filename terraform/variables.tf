# terraform/variables.tf

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Database password for blog application"
  type        = string
  sensitive   = true
  default     = "BlogSecure123!"
}

variable "instance_name" {
  description = "Name for the Lightsail instance"
  type        = string
  default     = "blog-server"
}