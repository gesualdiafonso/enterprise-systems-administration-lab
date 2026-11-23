# -----------------------------------------------------------------------------
# AWS provider. default_tags are applied to every taggable resource, so the
# whole lab can be found with: --filters Name=tag:Project,Values=ESAL
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
