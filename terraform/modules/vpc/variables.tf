# Define the AWS region to deploy resources in
variable "aws_region" {
  description = "AWS region"      # A short description for documentation
  type        = string            # The type must be a string
  default     = "eu-west-1"       # Default value (Ireland region)
}