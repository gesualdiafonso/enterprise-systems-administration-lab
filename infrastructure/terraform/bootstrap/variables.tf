variable "aws_region" {
  description = "AWS region where the Terraform state bucket is created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project tag value applied to every resource."
  type        = string
  default     = "enterprise-systems-administration-lab"
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "lab"
}

variable "state_bucket_prefix" {
  description = "Prefix of the state bucket name. Account ID and region are appended for global uniqueness."
  type        = string
  default     = "nexora-tfstate"
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep previous (noncurrent) versions of the state file before S3 expires them."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_retention_days >= 30
    error_message = "Keep at least 30 days of state history for recovery."
  }
}
