# -----------------------------------------------------------------------------
# Root variables. Defaults follow the approved architecture (CLAUDE.md §4) and
# docs/architecture/network-topology.md. Override in terraform.tfvars.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for all lab resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Value of the Project tag on every resource."
  type        = string
  default     = "ESAL"
}

variable "environment" {
  description = "Value of the Environment tag."
  type        = string
  default     = "lab"
}

variable "name_prefix" {
  description = "Prefix for resource Name tags (nexora-<component>)."
  type        = string
  default     = "nexora"
}

variable "availability_zone" {
  description = "Single AZ used by the lab. Confirm it offers the chosen instance types (see day02-preflight.sh)."
  type        = string
  default     = "us-east-1a"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR of nexora-vpc."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR of the public subnet (NX-DC01, NX-LNX01)."
  type        = string
  default     = "10.20.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "private_subnet_cidr" {
  description = "IPv4 CIDR reserved for the private subnet."
  type        = string
  default     = "10.20.2.0/24"

  validation {
    condition     = can(cidrhost(var.private_subnet_cidr, 0))
    error_message = "private_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "create_private_subnet" {
  description = "Create the reserved private subnet. Disabled by default: no workload uses it yet."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Day 02 - NX-DC01
# -----------------------------------------------------------------------------

variable "create_dc" {
  description = "Create NX-DC01. Keep false until Day 01 is applied and validated (EC2 costs start on creation)."
  type        = bool
  default     = false
}

variable "dc_ami_id" {
  description = "Pin a specific Windows Server 2022 AMI ID. null = latest from the AWS public SSM parameter."
  type        = string
  default     = null

  validation {
    condition     = var.dc_ami_id == null || can(regex("^ami-[0-9a-f]{8,17}$", var.dc_ami_id))
    error_message = "dc_ami_id must look like ami-0123456789abcdef0."
  }
}

variable "dc_instance_type" {
  description = "NX-DC01 instance type. Proposal: 2 vCPU / 4 GiB. Verify AZ offering with day02-preflight.sh."
  type        = string
  default     = "t3.medium"
}

variable "dc_cpu_credits" {
  description = "Burstable CPU credit mode: unlimited (no throttling, may add charges) or standard (throttles at baseline)."
  type        = string
  default     = "unlimited"

  validation {
    condition     = contains(["standard", "unlimited"], var.dc_cpu_credits)
    error_message = "dc_cpu_credits must be standard or unlimited."
  }
}

variable "dc_root_volume_size_gb" {
  description = "Root gp3 volume size in GiB (the AMI minimum is 30)."
  type        = number
  default     = 50

  validation {
    condition     = var.dc_root_volume_size_gb >= 30 && var.dc_root_volume_size_gb <= 200
    error_message = "dc_root_volume_size_gb must be between 30 and 200."
  }
}

variable "dc_private_ip" {
  description = "Fixed private IPv4 of NX-DC01. Must be inside public_subnet_cidr and not one of the 5 AWS-reserved addresses."
  type        = string
  default     = "10.20.1.10"

  validation {
    condition = (
      can(cidrhost("${var.dc_private_ip}/32", 0)) &&
      cidrhost("${var.dc_private_ip}/${split("/", var.public_subnet_cidr)[1]}", 0) == cidrhost(var.public_subnet_cidr, 0) &&
      !contains(
        [for i in [0, 1, 2, 3, -1] : cidrhost(var.public_subnet_cidr, i)],
        var.dc_private_ip
      )
    )
    error_message = "dc_private_ip must be a usable address inside public_subnet_cidr (not .0-.3 or the broadcast address)."
  }
}

variable "dc_termination_protection" {
  description = "Enable EC2 termination protection on NX-DC01."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Day 02 - Active Directory DNS / VPC DHCP option set
# -----------------------------------------------------------------------------

variable "ad_domain_name" {
  description = "Active Directory DNS domain."
  type        = string
  default     = "nexora.local"
}

variable "enable_ad_dhcp_options" {
  description = "Associate the nexora.local DHCP option set with the VPC. Enable ONLY after NX-DC01 DNS is healthy."
  type        = bool
  default     = false
}

variable "dhcp_dns_servers" {
  description = "DNS servers in the option set. null = [dc_private_ip, VPC resolver (VPC base + 2)]."
  type        = list(string)
  default     = null

  validation {
    condition     = var.dhcp_dns_servers == null || (length(var.dhcp_dns_servers) >= 1 && length(var.dhcp_dns_servers) <= 4)
    error_message = "A DHCP option set accepts between 1 and 4 DNS servers."
  }
}
