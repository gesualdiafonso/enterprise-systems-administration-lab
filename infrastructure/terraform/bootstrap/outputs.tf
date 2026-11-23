output "state_bucket_name" {
  description = "Name of the S3 bucket that stores the main Terraform state."
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_arn" {
  description = "ARN of the state bucket (used for least-privilege IAM policies)."
  value       = aws_s3_bucket.tfstate.arn
}

output "backend_config_snippet" {
  description = "Values to use in infrastructure/terraform/backend.tf."
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.tfstate.bucket}"
    key          = "esal/lab/terraform.tfstate"
    region       = "${var.aws_region}"
    encrypt      = true
    use_lockfile = true
  EOT
}
