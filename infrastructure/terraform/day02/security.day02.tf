# -----------------------------------------------------------------------------
# WIN-005 - Security Group for NX-DC01 (merge into security.tf)
# * NO inbound rule from the Internet (no RDP 3389, no WinRM, no SSH).
# * Administration happens through SSM (outbound HTTPS only).
# * AD/DNS ports are allowed ONLY from the VPC CIDR for future domain members.
# Note: Amazon DNS (VPC+2), IMDS and Amazon Time Sync traffic are not filtered
# by security groups.
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
  name        = "nexora-dc-sg"
  description = "NX-DC01 - no public admin ports; AD services from VPC only"
  vpc_id      = aws_vpc.nexora.id # <- adapt to the Day 01 VPC resource name

  tags = {
    Name    = "nexora-dc-sg"
    Project = var.project_name
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

# Outbound to the VPC: DC-initiated traffic to future domain members.
resource "aws_vpc_security_group_egress_rule" "dc_vpc" {
  security_group_id = aws_security_group.dc.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
  description       = "All traffic to hosts inside nexora-vpc"
}