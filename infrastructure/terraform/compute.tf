# -----------------------------------------------------------------------------
# Day 02 - NX-DC01 (Windows Server 2022, future Domain Controller of nexora.local)
# Design: docs/cloud/aws-design.md §5, docs/architecture/network-topology.md
#
#   WIN-001 AMI           latest AWS "Windows_Server-2022-English-Full-Base" from
#                         the public SSM parameter, or a pinned dc_ami_id
#   WIN-002 Instance type var.dc_instance_type (proposal 2 vCPU / 4 GiB)
#   WIN-003 Storage       encrypted gp3 root volume
#   WIN-004 Network       nexora-public-subnet-a, fixed private IP 10.20.1.10
#   WIN-005 Access        nexora-dc-sg (no inbound admin ports)
#   WIN-006 IAM           nexora-ec2-ssm-profile (SSM + CloudWatch agent)
#   WIN-007 Instance      NX-DC01, created only when var.create_dc = true
#
# No key pair: administration happens exclusively through SSM (Session Manager,
# Run Command, Fleet Manager). Hostname, timezone and AD DS are configured later
# with PowerShell through SSM - not in user data - so each step is auditable.
# -----------------------------------------------------------------------------

data "aws_ssm_parameter" "windows_2022_ami" {
  count = var.create_dc && var.dc_ami_id == null ? 1 : 0

  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

locals {
  dc_ami_id = var.dc_ami_id != null ? var.dc_ami_id : try(data.aws_ssm_parameter.windows_2022_ami[0].insecure_value, null)
}

resource "aws_instance" "dc" {
  count = var.create_dc ? 1 : 0

  ami           = local.dc_ami_id
  instance_type = var.dc_instance_type

  subnet_id                   = module.network.public_subnet_id
  private_ip                  = var.dc_private_ip
  associate_public_ip_address = true # outbound HTTPS to SSM without a NAT Gateway
  vpc_security_group_ids      = [aws_security_group.dc.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name

  # A domain controller is never disposable: block accidental termination.
  # Set dc_termination_protection = false before a planned destroy.
  disable_api_termination = var.dc_termination_protection

  monitoring = false # basic (free) CloudWatch metrics; agent added later

  credit_specification {
    cpu_credits = var.dc_cpu_credits
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.dc_root_volume_size_gb
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "NX-DC01-root"
    }
  }

  tags = {
    Name = "NX-DC01"
    Role = "DomainController"
    OS   = "WindowsServer2022"
  }

  lifecycle {
    # The SSM parameter moves to a new AMI every month. Without this, every
    # monthly AMI release would make Terraform REPLACE the domain controller.
    ignore_changes = [ami]

    precondition {
      condition     = local.dc_ami_id != null
      error_message = "No AMI resolved for NX-DC01. Check the SSM parameter or set dc_ami_id."
    }
  }
}
