# -----------------------------------------------------------------------------
# Network module - nexora-vpc (single AZ, no NAT Gateway, no interface endpoints)
# Design: docs/architecture/network-topology.md
#
#   nexora-vpc               10.20.0.0/16   DNS support + DNS hostnames enabled
#   nexora-igw               Internet Gateway (outbound for SSM / updates)
#   nexora-public-subnet-a   10.20.1.0/24   auto-assign public IPv4 (needed for
#                                           SSM over HTTPS without a NAT Gateway)
#   nexora-public-rt         0.0.0.0/0 -> nexora-igw
#   nexora-private-subnet-a  10.20.2.0/24   OPTIONAL, reserved, no Internet route
#   default security group   all rules removed (nothing should use it)
# -----------------------------------------------------------------------------

locals {
  # "us-east-1a" -> "a", used in subnet names (nexora-public-subnet-a).
  az_suffix = substr(var.availability_zone, -1, 1)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-subnet-${local.az_suffix}"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Reserved for future expansion. Not associated with the public route table,
# so it falls back to the VPC main route table (local route only, no Internet).
resource "aws_subnet" "private" {
  count = var.create_private_subnet ? 1 : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-private-subnet-${local.az_suffix}"
    Tier = "private"
  }
}

# Take control of the default security group and strip all its rules, so any
# resource accidentally launched without an explicit SG gets no connectivity.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-default-sg-unused"
  }
}
