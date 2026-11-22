# IP Addressing Plan

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | IP Addressing Plan |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | IPv4 fundamentals, CIDR, VPC and subnet calculations, allocation plan, expansion |

> **Status:** All allocations are **PROPOSED — PENDING IMPLEMENTATION**. No address has been
> assigned to any EC2 instance yet.

---

## 1. IPv4 Fundamentals

An IPv4 address is a 32-bit number written as four decimal octets (e.g. `10.20.1.10`). Each
address has a **network part** and a **host part**; the boundary is defined by the prefix length
(subnet mask).

| Notation | Example | Meaning |
|---|---|---|
| Dotted decimal | 10.20.1.10 | Human-readable address |
| Binary | 00001010.00010100.00000001.00001010 | What routers process |
| Prefix length | /24 | First 24 bits identify the network |
| Subnet mask | 255.255.255.0 | Same as /24 |

**Private ranges (RFC 1918)** — not routable on the Internet:

| Range | CIDR |
|---|---|
| 10.0.0.0 – 10.255.255.255 | 10.0.0.0/8 |
| 172.16.0.0 – 172.31.255.255 | 172.16.0.0/12 |
| 192.168.0.0 – 192.168.255.255 | 192.168.0.0/16 |

The project uses `10.20.0.0/16`, inside 10.0.0.0/8.

## 2. CIDR Explained

Classless Inter-Domain Routing (CIDR) expresses a network as `address/prefix`. The number of
addresses is `2^(32 − prefix)`.

| Prefix | Addresses | Typical use |
|---|---|---|
| /16 | 65,536 | VPC (the largest IPv4 CIDR a VPC accepts) |
| /20 | 4,096 | Large subnet |
| /24 | 256 | Standard lab subnet |
| /28 | 16 | Smallest subnet AWS allows |
| /32 | 1 | Single host (e.g. in Security Group rules) |

## 3. VPC Addressing

| Item | Value |
|---|---|
| VPC CIDR | 10.20.0.0/16 |
| First address | 10.20.0.0 |
| Last address | 10.20.255.255 |
| Total addresses | 65,536 |
| Possible /24 subnets | 256 (10.20.0.0/24 … 10.20.255.0/24) |
| Amazon-provided DNS resolver | **10.20.0.2** (VPC base address + 2); also reachable at 169.254.169.253 |

**Why 10.20.0.0/16?** It leaves ample room for growth and avoids the ranges most often used by
home routers (192.168.0.0/24, 192.168.1.0/24) and many default VPCs (172.31.0.0/16), which
reduces overlap problems if a VPN to a workstation or office is added later.

## 4. Subnet Calculations

### 4.1 Public subnet — 10.20.1.0/24

| Field | Value |
|---|---|
| Network address | 10.20.1.0 |
| Subnet mask | 255.255.255.0 |
| Total addresses | 256 |
| AWS-reserved | 5 (see §6) |
| Assignable to instances | 251 (10.20.1.4 – 10.20.1.254) |
| Last address | 10.20.1.255 |

### 4.2 Private subnet — 10.20.2.0/24 (RESERVED, NOT DEPLOYED)

| Field | Value |
|---|---|
| Network address | 10.20.2.0 |
| Assignable once created | 251 (10.20.2.4 – 10.20.2.254) |
| Status | Reserved in the plan; no Terraform resource |

## 5. Private and Public IP Behaviour on EC2

| Property | Private IPv4 | Auto-assigned public IPv4 | Elastic IP |
|---|---|---|---|
| Source | Subnet CIDR | Amazon pool | Allocated to the account |
| Persistence | Kept while the ENI exists (survives stop/start) | **Released on stop**, new one on start | Persistent until released |
| Can be chosen | Yes (`private_ip` at launch) | No | Yes (allocate/associate) |
| Visible inside the OS | Yes | No (the OS only sees the private IP; translation happens at the IGW) | No |
| Charged | No | **Yes, while assigned** | **Yes**, assigned or idle |
| Used in this project | Yes — static, proposed below | Yes — outbound only | **No** (avoid permanent EIPs) |

Because no inbound connection from the Internet is used, a changing public IP has no functional
impact on the lab.

## 6. Reserved Addresses in Every AWS Subnet

AWS reserves the first four and the last address of each subnet:

| Address (public subnet) | Reservation |
|---|---|
| 10.20.1.0 | Network address |
| 10.20.1.1 | VPC router |
| 10.20.1.2 | Reserved by AWS (DNS-related reservation) |
| 10.20.1.3 | Reserved for future use |
| 10.20.1.255 | Network broadcast (broadcast is not supported in a VPC, but the address is reserved) |

> The VPC's DNS resolver lives at the **VPC** base + 2 (**10.20.0.2**), which is inside
> 10.20.0.0/24 — a range we deliberately leave unallocated.

## 7. Recommended Allocation Table — Public Subnet 10.20.1.0/24

| Range | Function | Status |
|---|---|---|
| 10.20.1.0 – 10.20.1.3 | AWS reserved | Fixed by AWS |
| 10.20.1.4 – 10.20.1.9 | Technical reserve | PROPOSED |
| 10.20.1.10 – 10.20.1.19 | Identity infrastructure (Domain Controllers) | PROPOSED |
| 10.20.1.20 – 10.20.1.29 | Linux servers | PROPOSED |
| 10.20.1.30 – 10.20.1.99 | Future servers | PROPOSED |
| 10.20.1.100 – 10.20.1.199 | **Windows DHCP educational scope** (documentation only — not served to EC2) | PROPOSED |
| 10.20.1.200 – 10.20.1.254 | AWS dynamic assignment for temporary instances | PROPOSED |
| 10.20.1.255 | AWS reserved | Fixed by AWS |

### 7.1 Proposed host allocations

| Hostname | Proposed private IP | Proposed FQDN | Assignment method | Status |
|---|---|---|---|---|
| NX-DC01 | 10.20.1.10 | nx-dc01.nexora.local | `private_ip` argument at launch (Terraform) | PROPOSED — PENDING IMPLEMENTATION |
| NX-LNX01 | 10.20.1.20 | nx-lnx01.nexora.local | `private_ip` argument at launch (Terraform) | PROPOSED — PENDING IMPLEMENTATION |

> **Rule:** never configure a static IP *inside* the guest OS on EC2. The address is fixed at the
> AWS network-interface level and delivered by AWS DHCP; changing the OS adapter manually can cut
> the instance off from the network and from Systems Manager.

## 8. DNS Server IP Reservation

| DNS server | IP | Role | When |
|---|---|---|---|
| Amazon-provided resolver | 10.20.0.2 | Public names, AWS internal names; forwarder target for the DC | Always available |
| NX-DC01 (Windows DNS) | 10.20.1.10 (proposed) | Authoritative for `nexora.local` | After AD DS promotion |

The DC address is reserved first because every domain member depends on it for DNS. See
[dns.md](dns.md).

## 9. Network Expansion Strategy

| Block | Planned use |
|---|---|
| 10.20.0.0/24 | Left unallocated (contains the VPC resolver address) |
| 10.20.1.0/24 | Public subnet, AZ a — in use |
| 10.20.2.0/24 | Private subnet, AZ a — reserved |
| 10.20.11.0/24 | Public subnet, AZ b — future HA |
| 10.20.12.0/24 | Private subnet, AZ b — future HA |
| 10.20.100.0/22 | Future VPN / remote-site ranges |
| Remaining | Unallocated |

Convention: the **third octet's tens digit** identifies the AZ (0x = a, 1x = b), the **units digit**
identifies the tier (1 = public, 2 = private).

## 10. Validation (post-deployment)

```bash
aws ec2 describe-instances --filters Name=tag:Project,Values=ESAL \
  --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,PrivateIpAddress,PublicIpAddress]" \
  --output table
```

```powershell
# On NX-DC01 (Session Manager)
Get-NetIPConfiguration
```

```bash
# On NX-LNX01 (Session Manager)
ip -4 addr show
ip route
```

| Check | Expected | Status |
|---|---|---|
| NX-DC01 private IP | 10.20.1.10 | NOT TESTED |
| NX-LNX01 private IP | 10.20.1.20 | NOT TESTED |
| Default gateway inside OS | 10.20.1.1 | NOT TESTED |

## References

- AWS — Subnet CIDR blocks (reserved addresses): <https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html>
- AWS — VPC CIDR blocks: <https://docs.aws.amazon.com/vpc/latest/userguide/vpc-cidr-blocks.html>
- AWS — Amazon EC2 instance IP addressing: <https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-instance-addressing.html>
- AWS — Amazon VPC pricing (public IPv4): <https://aws.amazon.com/vpc/pricing/>
- IETF — RFC 1918: <https://www.rfc-editor.org/rfc/rfc1918>
- IETF — RFC 4632, Classless Inter-domain Routing (CIDR): <https://www.rfc-editor.org/rfc/rfc4632>
