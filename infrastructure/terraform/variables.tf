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
