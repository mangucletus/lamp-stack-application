terraform {
  required_version = ">= 1.0" # Ensure Terraform version compatibility
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use AWS provider v5.x
    }
  }
  backend "s3" {
    bucket = "lamp-stack-tfstate-cletusmangu-1749764715" # Remote state storage bucket
    key    = "lamp-stack/terraform.tfstate"              # Path to store the state file
    region = "eu-west-1"                                 # Region for the bucket
  }
}

provider "aws" {
  region = var.aws_region # Use variable for region flexibility
}

# VPC Module
module "vpc" {
  source     = "./modules/vpc"
  aws_region = var.aws_region
}

# Security Module
module "security" {
  source = "./modules/security"
  vpc_id = module.vpc.vpc_id
}

# Compute Module
module "compute" {
  source            = "./modules/compute"
  aws_region        = var.aws_region
  instance_type     = var.instance_type
  key_name          = var.key_name
  public_key        = var.public_key
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.security.security_group_id
}