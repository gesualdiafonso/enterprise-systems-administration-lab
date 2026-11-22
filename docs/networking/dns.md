# DNS Design

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | DNS Design |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | DNS fundamentals, Windows DNS, AD-integrated zones, AWS resolver, DHCP option set, troubleshooting |

> **Status:** DNS design is **PROPOSED / NOT DEPLOYED / NOT TESTED**.

---

## 1. DNS Fundamentals

The Domain Name System translates names (e.g. `nx-dc01.nexora.local`) into IP addresses and
provides service discovery. Active Directory **cannot function without DNS**: clients locate
Domain Controllers by querying DNS SRV records.

| Term | Meaning |
|---|---|
| Resolver (client) | Component on a host that sends queries |
| Recursive server | Server that chases the answer on behalf of the client |
| Authoritative server | Server that holds the zone data for a namespace |
| Zone | Administrative unit of the namespace stored on a server |
| TTL | How long a cached answer remains valid |

## 2. DNS Hierarchy

```text
.                     (root)
└── local             (special-use: reserved for Multicast DNS, never delegated publicly)
    └── nexora        (nexora.local — private AD domain, authoritative on NX-DC01)
        ├── nx-dc01
        ├── nx-lnx01
        └── _msdcs, _tcp, _udp, _sites ... (AD service records)
```

Public names (e.g. `archive.ubuntu.com`) follow the normal delegation chain from the root servers.

## 3. Forward and Reverse Resolution

| Type | Question | Zone | Example |
|---|---|---|---|
| Forward | Name → IP | `nexora.local` | `nx-dc01.nexora.local → 10.20.1.10` |
| Reverse | IP → name | `1.20.10.in-addr.arpa` | `10.20.1.10 → nx-dc01.nexora.local` |

Reverse zones are named by reversing the network octets and appending `in-addr.arpa`.

## 4. Windows DNS Server

NX-DC01 runs the Windows DNS Server role, installed automatically when AD DS is promoted with the
DNS option. It will:

- Host the AD-integrated forward zone `nexora.local` and the `_msdcs.nexora.local` zone.
- Host the reverse zone `1.20.10.in-addr.arpa` (to be created manually — PLANNED).
- Forward all other queries to the Amazon-provided resolver (**10.20.0.2**).
- Accept **secure dynamic updates** only (default for AD-integrated zones).

## 5. Active Directory-Integrated DNS

In an AD-integrated zone, records are stored in Active Directory instead of a text zone file.

| Benefit | Explanation |
|---|---|
| Replication | Zone data replicates with AD to other DCs (relevant if a second DC is added) |
| Secure dynamic update | Only authenticated domain members can register/update their records |
| Multi-master | Any DC hosting the zone can accept updates |

## 6. DNS Zones (PROPOSED)

| Zone | Type | Replication scope | Dynamic updates | Status |
|---|---|---|---|---|
| `nexora.local` | Primary, AD-integrated | All DNS servers in the domain | Secure only | PROPOSED |
| `_msdcs.nexora.local` | Primary, AD-integrated | All DNS servers in the forest | Secure only | Created by promotion |
| `1.20.10.in-addr.arpa` | Primary, AD-integrated (reverse) | All DNS servers in the domain | Secure only | PLANNED |

## 7. Record Types

| Record | Purpose | Example in this project | Status |
|---|---|---|---|
| A | Name → IPv4 | `nx-dc01 A 10.20.1.10` | PROPOSED |
| AAAA | Name → IPv6 | Not used (IPv6 out of scope) | — |
| CNAME | Alias → canonical name | `intranet CNAME nx-lnx01.nexora.local` | PROPOSED |
| PTR | IPv4 → name (reverse) | `10 PTR nx-dc01.nexora.local` in `1.20.10.in-addr.arpa` | PLANNED |
| SRV | Service location | `_ldap._tcp.dc._msdcs.nexora.local` → nx-dc01, port 389 | Created by AD |

## 8. Forwarders

| Setting | Value | Reason |
|---|---|---|
| Forwarder | 10.20.0.2 | The Amazon-provided resolver resolves public names and AWS-internal names, including the regional AWS service endpoints that the SSM Agent needs |
| Use root hints if forwarders unavailable | Optional | Keep enabled as a fallback |

> Forwarding to the VPC resolver instead of public DNS servers keeps resolution inside AWS and
> ensures AWS-specific names resolve correctly.

## 9. AWS VPC DNS Resolver

| Attribute | Value |
|---|---|
| Name | Amazon-provided DNS / Route 53 Resolver |
| Address | VPC base + 2 → **10.20.0.2**; also 169.254.169.253 |
| Requirement | `enableDnsSupport = true` on the VPC |
| Resolves | Public DNS, EC2 internal hostnames, Route 53 private hosted zones (if any) |
| Does **not** resolve | `nexora.local` (unless a Resolver rule is added — out of scope) |

## 10. Relationship with the DHCP Option Set

EC2 instances learn their DNS servers through AWS VPC DHCP. The values are defined by the VPC's
**DHCP option set** (see [dhcp.md](dhcp.md)).

| Phase | `domain-name-servers` | `domain-name` | Effect |
|---|---|---|---|
| Before AD (default set) | `AmazonProvidedDNS` | AWS default (e.g. `ec2.internal` in us-east-1) | Instances use 10.20.0.2 |
| After AD (custom set `nexora-dhcp-options`) | `10.20.1.10` and a fallback (**VALIDATION REQUIRED**) | `nexora.local` | Instances use the DC |

**Design caution (VALIDATION REQUIRED):** if the DC is the only DNS server and it stops, every
instance loses name resolution — including resolution of the SSM endpoints, which can break
Session Manager. Options to evaluate on Day 04:

1. List the DC first and the AWS resolver second, accepting that a client may sometimes ask the
   AWS resolver for `nexora.local` names it cannot answer.
2. Keep `AmazonProvidedDNS` in the option set and configure only domain members' OS-level DNS
   to point to the DC.

NX-DC01 itself should use `127.0.0.1` (and its own private IP) as DNS server after promotion,
following Microsoft guidance for DCs.

## 11. Internal Domain `nexora.local`

| Item | Value |
|---|---|
| DNS domain | `nexora.local` (approved project decision) |
| NetBIOS name | `NEXORA` (proposed) |
| Authoritative server | NX-DC01 |

**Technical note on `.local`:** RFC 6762 reserves `.local` for Multicast DNS. macOS (Bonjour) and
some Linux systems (Avahi) treat `.local` names as mDNS by default, which can make lookups from a
macOS workstation fail or be slow. Microsoft recommends using a subdomain of a registered domain
for new forests. The project keeps `nexora.local` as an approved decision because the domain is
only resolved **inside the VPC**, never from the workstations; this trade-off is recorded in
[domain-structure.md](domain-structure.md).

## 12. DNS Troubleshooting

| Symptom | Likely cause | Check |
|---|---|---|
| Clients cannot find the domain | SRV records missing | `nslookup -type=SRV _ldap._tcp.dc._msdcs.nexora.local` |
| Public names fail on the DC | Forwarder missing/wrong | `Get-DnsServerForwarder` |
| Name resolves to old IP | Stale cache | `Clear-DnsClientCache`; `resolvectl flush-caches` |
| Reverse lookup fails | No PTR / no reverse zone | `Resolve-DnsName 10.20.1.10` |
| SSM stops working after DNS change | Instances cannot resolve SSM endpoints | `Resolve-DnsName ssm.us-east-1.amazonaws.com` |
| Linux ignores the DC | `systemd-resolved` still using old DHCP data | `resolvectl status`, renew lease or reboot |

## 13. Validation Commands (post-deployment)

```powershell
# On NX-DC01
Get-DnsServerZone
Get-DnsServerResourceRecord -ZoneName "nexora.local" -RRType A
Get-DnsServerForwarder
Resolve-DnsName nx-dc01.nexora.local
Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.nexora.local
Resolve-DnsName ssm.us-east-1.amazonaws.com
dcdiag /test:dns
```

```bash
# On NX-LNX01
resolvectl status
dig +short nx-dc01.nexora.local
dig +short -x 10.20.1.10
dig +short SRV _ldap._tcp.dc._msdcs.nexora.local
```

| Check | Expected | Status |
|---|---|---|
| Forward lookup of NX-DC01 | 10.20.1.10 | NOT TESTED |
| SRV lookup | Returns nx-dc01.nexora.local:389 | NOT TESTED |
| Forwarder | 10.20.0.2 | NOT TESTED |
| `dcdiag /test:dns` | No failures | NOT TESTED |

## References

- Microsoft — DNS in Windows Server: <https://learn.microsoft.com/en-us/windows-server/networking/dns/dns-top>
- Microsoft — Selecting the forest root domain: <https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/selecting-the-forest-root-domain>
- Microsoft — DnsServer PowerShell module: <https://learn.microsoft.com/en-us/powershell/module/dnsserver/>
- AWS — DNS attributes for your VPC: <https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html>
- AWS — DHCP option sets in Amazon VPC: <https://docs.aws.amazon.com/vpc/latest/userguide/VPC_DHCP_Options.html>
- Ubuntu — systemd-resolved / name resolution: <https://documentation.ubuntu.com/server/>
- IETF — RFC 1034 / RFC 1035 (DNS): <https://www.rfc-editor.org/rfc/rfc1034> · <https://www.rfc-editor.org/rfc/rfc1035>
- IETF — RFC 6762, Multicast DNS: <https://www.rfc-editor.org/rfc/rfc6762>
