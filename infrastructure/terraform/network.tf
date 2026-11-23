# -----------------------------------------------------------------------------
# Day 01 - Network foundation (nexora-vpc). See modules/network.
# -----------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  name_prefix           = var.name_prefix
  availability_zone     = var.availability_zone
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  private_subnet_cidr   = var.private_subnet_cidr
  create_private_subnet = var.create_private_subnet
}
