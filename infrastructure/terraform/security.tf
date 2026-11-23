# -----------------------------------------------------------------------------
# Security groups. Design: docs/networking/security-groups.md
#
# WIN-005 - nexora-dc-sg (NX-DC01), merged from day02/security.day02.tf
#   * NO inbound rule from the Internet (no RDP 3389, no WinRM, no SSH).
#   * Administration happens through SSM (outbound HTTPS only).
#   * AD/DNS ports are allowed ONLY from the VPC CIDR for future domain members.
#
# Traffic to the Amazon DNS resolver (VPC+2 / 169.254.169.253), IMDS
# (169.254.169.254) and Amazon Time Sync (169.254.169.123) is not filtered by
# security groups, so no rules are needed for it.
# -----------------------------------------------------------------------------

locals {
  dc_ingress_rules = {
    dns_tcp      = { protocol = "tcp", from = 53, to = 53, desc = "DNS (TCP) from VPC" }
    dns_udp      = { protocol = "udp", from = 53, to = 53, desc = "DNS (UDP) from VPC" }
    kerberos_tcp = { protocol = "tcp", from = 88, to = 88, desc = "Kerberos (TCP) from VPC" }
    kerberos_udp = { protocol = "udp", from = 88, to = 88, desc = "Kerberos (UDP) from VPC" }
    ntp_udp      = { protocol = "udp", from = 123, to = 123, desc = "W32Time/NTP from VPC" }
    rpc_epm_tcp  = { protocol = "tcp", from = 135, to = 135, desc = "RPC endpoint mapper from VPC" }
    ldap_tcp     = { protocol = "tcp", from = 389, to = 389, desc = "LDAP (TCP) from VPC" }
    ldap_udp     = { protocol = "udp", from = 389, to = 389, desc = "LDAP (UDP/CLDAP) from VPC" }
    smb_tcp      = { protocol = "tcp", from = 445, to = 445, desc = "SMB (SYSVOL/NETLOGON) from VPC" }
    kpasswd_tcp  = { protocol = "tcp", from = 464, to = 464, desc = "Kerberos password change (TCP)" }
    kpasswd_udp  = { protocol = "udp", from = 464, to = 464, desc = "Kerberos password change (UDP)" }
    ldaps_tcp    = { protocol = "tcp", from = 636, to = 636, desc = "LDAPS from VPC" }
    gc_tcp       = { protocol = "tcp", from = 3268, to = 3269, desc = "Global Catalog from VPC" }
    rpc_dyn_tcp  = { protocol = "tcp", from = 49152, to = 65535, desc = "RPC dynamic ports from VPC" }
  }
}

resource "aws_security_group" "dc" {
  name        = "${var.name_prefix}-dc-sg"
  description = "NX-DC01 - no public admin ports; AD services from VPC only"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "${var.name_prefix}-dc-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "dc_ad" {
  for_each = local.dc_ingress_rules

  security_group_id = aws_security_group.dc.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = each.value.protocol
  from_port         = each.value.from
  to_port           = each.value.to
  description       = each.value.desc
}

# Outbound HTTPS: SSM, EC2 messages, SSM messages, S3, Windows Update, PSGallery.
resource "aws_vpc_security_group_egress_rule" "dc_https" {
  security_group_id = aws_security_group.dc.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to AWS endpoints and Windows Update"
}

# Outbound HTTP: some Windows Update / CRL / OCSP endpoints still use TCP 80.
resource "aws_vpc_security_group_egress_rule" "dc_http" {
  security_group_id = aws_security_group.dc.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "HTTP for Windows Update, CRL and OCSP"
}

# Windows license activation against the AWS KMS servers (link-local, TCP 1688).
resource "aws_vpc_security_group_egress_rule" "dc_kms_activation" {
  for_each = toset(["169.254.169.250/32", "169.254.169.251/32"])

  security_group_id = aws_security_group.dc.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 1688
  to_port           = 1688
  description       = "Windows activation via AWS KMS servers"
}

# Outbound to the VPC: DC-initiated traffic to future domain members.
resource "aws_vpc_security_group_egress_rule" "dc_vpc" {
  security_group_id = aws_security_group.dc.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
  description       = "All traffic to hosts inside nexora-vpc"
}
