# -----------------------------------------------------------------------------
# Bootstrap configuration - Terraform and provider version constraints.
# This configuration uses LOCAL state on purpose: it creates the S3 bucket that
# the main configuration will later use as its remote backend.
# -----------------------------------------------------------------------------
terraform {
  # 1.11+ is required for S3 native state locking (use_lockfile) in the main config.
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Component   = "terraform-state-bootstrap"
    }
  }
}
