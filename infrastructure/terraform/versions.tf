# -----------------------------------------------------------------------------
# Terraform and provider version constraints for the main configuration.
# 1.11+ is required for S3 native state locking (use_lockfile in backend.tf).
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
