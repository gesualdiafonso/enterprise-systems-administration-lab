# -----------------------------------------------------------------------------
# DHCP-001..003 - Custom VPC DHCP option set for nexora.local
# Design: docs/networking/dhcp.md §6, docs/networking/dns.md §10
#
# AWS VPC DHCP keeps assigning every EC2 address. This option set only changes
# WHAT is handed out: domain name nexora.local and the DNS servers.
#
#   domain-name          nexora.local
#   domain-name-servers  10.20.1.10 (NX-DC01) first, AWS resolver (VPC+2) second
#
# ENABLE ONLY AFTER NX-DC01 IS PROMOTED AND ITS DNS IS HEALTHY.
# If instances are told to use a DC that is not answering DNS yet, they cannot
# resolve the SSM endpoints and Session Manager / Fleet Manager stop working.
#
# Disabling (enable_ad_dhcp_options = false) destroys the association and the
# VPC falls back to the AWS "default" option set (AmazonProvidedDNS).
# Clients pick up changes on DHCP lease renewal (ipconfig /renew, or reboot).
# -----------------------------------------------------------------------------

locals {
  # The Amazon-provided resolver always sits at the VPC base address + 2.
  vpc_dns_resolver_ip = cidrhost(var.vpc_cidr, 2)

  dhcp_dns_servers = coalesce(var.dhcp_dns_servers, [var.dc_private_ip, local.vpc_dns_resolver_ip])
}

resource "aws_vpc_dhcp_options" "nexora" {
  count = var.enable_ad_dhcp_options ? 1 : 0

  domain_name         = var.ad_domain_name
  domain_name_servers = local.dhcp_dns_servers

  tags = {
    Name = "${var.name_prefix}-dhcp-options"
  }

  lifecycle {
    precondition {
      condition     = var.create_dc
      error_message = "enable_ad_dhcp_options requires create_dc = true: the option set points clients to NX-DC01."
    }
  }
}

resource "aws_vpc_dhcp_options_association" "nexora" {
  count = var.enable_ad_dhcp_options ? 1 : 0

  vpc_id          = module.network.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.nexora[0].id
}
