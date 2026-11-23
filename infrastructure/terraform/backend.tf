# -----------------------------------------------------------------------------
# Remote state in the S3 bucket created by ./bootstrap.
#
# Partial configuration: the bucket name contains the AWS account ID, so it is
# NOT written here. It is supplied at init time from a local, git-ignored file:
#
#   cp backend.hcl.example backend.hcl     # then set the bucket name
#   terraform init -backend-config=backend.hcl
#
# use_lockfile = true -> S3 native locking (<key>.tflock), no DynamoDB table.
# -----------------------------------------------------------------------------
terraform {
  backend "s3" {
    key          = "esal/lab/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
