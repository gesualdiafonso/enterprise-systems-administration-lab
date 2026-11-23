# -----------------------------------------------------------------------------
# Offline tests (no AWS credentials needed): terraform test
# The AWS provider is mocked, so these tests check Terraform logic only -
# variable validation, counts/toggles, preconditions and computed values.
# They do NOT prove that AWS accepts the configuration (use terraform plan).
# -----------------------------------------------------------------------------

mock_provider "aws" {
  override_data {
    target = data.aws_ssm_parameter.windows_2022_ami
    values = {
      insecure_value = "ami-0123456789abcdef0"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "day01_defaults_create_no_ec2" {
  command = plan

  assert {
    condition     = length(aws_instance.dc) == 0
    error_message = "NX-DC01 must not be created by default."
  }
  assert {
    condition     = length(aws_vpc_dhcp_options.nexora) == 0
    error_message = "DHCP option set must be disabled by default."
  }
  assert {
    condition     = length(module.network.private_subnet_id == null ? [] : [1]) == 0
    error_message = "Private subnet must not be created by default."
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.dc_ad) == 14
    error_message = "Expected 14 AD/DNS ingress rules on nexora-dc-sg."
  }
  assert {
    condition     = alltrue([for r in aws_vpc_security_group_ingress_rule.dc_ad : r.cidr_ipv4 == "10.20.0.0/16"])
    error_message = "DC ingress must be limited to the VPC CIDR."
  }
}

run "dc_enabled" {
  command = plan

  variables {
    create_dc = true
  }

  assert {
    condition     = aws_instance.dc[0].private_ip == "10.20.1.10"
    error_message = "NX-DC01 must use 10.20.1.10."
  }
  assert {
    condition     = aws_instance.dc[0].ami == "ami-0123456789abcdef0"
    error_message = "AMI must come from the SSM parameter when dc_ami_id is null."
  }
  assert {
    condition     = aws_instance.dc[0].metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }
  assert {
    condition     = aws_instance.dc[0].root_block_device[0].encrypted && aws_instance.dc[0].root_block_device[0].volume_type == "gp3"
    error_message = "Root volume must be encrypted gp3."
  }
  assert {
    condition     = aws_instance.dc[0].tags["Name"] == "NX-DC01"
    error_message = "Instance Name tag must be NX-DC01."
  }
}

run "dc_with_pinned_ami" {
  command = plan

  variables {
    create_dc = true
    dc_ami_id = "ami-0fedcba9876543210"
  }

  assert {
    condition     = aws_instance.dc[0].ami == "ami-0fedcba9876543210"
    error_message = "Pinned dc_ami_id must win over the SSM parameter."
  }
}

run "dhcp_options_after_ad" {
  command = plan

  variables {
    create_dc              = true
    enable_ad_dhcp_options = true
  }

  assert {
    condition     = aws_vpc_dhcp_options.nexora[0].domain_name == "nexora.local"
    error_message = "Option set must hand out nexora.local."
  }
  assert {
    condition     = aws_vpc_dhcp_options.nexora[0].domain_name_servers == tolist(["10.20.1.10", "10.20.0.2"])
    error_message = "DNS servers must be the DC first, then the VPC resolver."
  }
}

run "dhcp_options_without_dc_is_rejected" {
  command = plan

  variables {
    create_dc              = false
    enable_ad_dhcp_options = true
  }

  expect_failures = [aws_vpc_dhcp_options.nexora]
}

run "dc_ip_outside_subnet_is_rejected" {
  command = plan

  variables {
    dc_private_ip = "10.20.2.10"
  }

  expect_failures = [var.dc_private_ip]
}

run "dc_ip_aws_reserved_is_rejected" {
  command = plan

  variables {
    dc_private_ip = "10.20.1.2"
  }

  expect_failures = [var.dc_private_ip]
}
