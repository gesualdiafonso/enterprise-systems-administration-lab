variable "name_prefix" {
  description = "Prefix for Name tags (e.g. nexora)."
  type        = string
}

variable "availability_zone" {
  description = "AZ for the subnets."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR of the VPC."
  type        = string
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR of the public subnet."
  type        = string
}

variable "private_subnet_cidr" {
  description = "IPv4 CIDR of the reserved private subnet."
  type        = string
}

variable "create_private_subnet" {
  description = "Whether to create the reserved private subnet."
  type        = bool
  default     = false
}
