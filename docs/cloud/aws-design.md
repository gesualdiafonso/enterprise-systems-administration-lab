# AWS Design

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | AWS Design |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | Design principles, service-by-service design, network design, deployment sequence, security, availability, cost, limitations, expansion |

> **Status:** **PROPOSED / NOT DEPLOYED.** This document explains *why* the architecture in
> [aws-architecture.md](../architecture/aws-architecture.md) looks the way it does.

---

## 1. AWS Design Principles

| Principle | Application in ESAL |
|---|---|
| Everything as code | VPC, SGs, IAM, EC2 and CloudWatch defined in Terraform |
| Least privilege | Scoped IAM, SG-to-SG rules, no admin ports |
| Temporary credentials | IAM Identity Center for humans, instance profiles for workloads |
| Cost awareness | No NAT Gateway, no idle endpoints, stop when idle |
| Simplicity over HA | One AZ, one DC — limitations explicitly documented |
| Observability | CloudWatch metrics and logs from the start |
| Honest documentation | Proposed vs deployed always distinguished |

These align with the AWS Well-Architected pillars (operational excellence, security, reliability,
performance efficiency, cost optimisation, sustainability), with **reliability intentionally
traded down** for cost in a lab.

## 2. Region

| Item | Value |
|---|---|
| Initial target | `us-east-1` |
| Status | **VALIDATION REQUIRED** — confirm service and instance availability, pricing, and account restrictions |
| Implementation | Terraform variable `aws_region` |

## 3. VPC

| Decision | Reason |
|---|---|
| Custom VPC instead of default VPC | Controlled CIDR, explicit routing, clean teardown |
| CIDR 10.20.0.0/16 | Room for growth; avoids common overlaps |
| DNS support + hostnames enabled | Needed for the Amazon resolver and SSM |
| One public subnet in use, one private subnet reserved | Cost; clear expansion path |

## 4. EC2

| Decision | Reason |
|---|---|
| AMIs resolved from SSM public parameters | Always the current official image; no hard-coded AMI IDs |
| Static private IPs via `private_ip` | Stable DC address for DNS; predictable documentation |
| IMDSv2 required | Mitigates credential theft via SSRF |
| Encrypted gp3 root volumes | Security by default; gp3 is cost-effective |
| No key pairs | Access exclusively via SSM |
| Burstable instance family (candidate) | Low average utilisation in a lab — VALIDATION REQUIRED |

## 5. Windows Server (NX-DC01)

| Item | Design |
|---|---|
| Image | Windows Server 2022 English Full Base (Desktop Experience) |
| Sizing proposal | 2 vCPU / 4 GiB RAM — subject to availability and pricing validation |
| Roles | AD DS, DNS, Group Policy; DHCP role educational |
| Hostname | Set to `NX-DC01` before promotion |
| Special consideration | `ssm-user` must be handled manually on a DC ([systems-manager.md](systems-manager.md#8-domain-controller-consideration-ssm-user)) |

## 6. Ubuntu Server (NX-LNX01)

| Item | Design |
|---|---|
| Image | Canonical Ubuntu Server 24.04 LTS (amd64, gp3) |
| Sizing proposal | 2 vCPU / 2 GiB RAM — subject to validation |
| Services | Nginx, MariaDB (localhost), UFW, Fail2ban |
| Hostname | `nx-lnx01` |

## 7. IAM

| Component | Design |
|---|---|
| Human access | IAM Identity Center user + permission set; MFA |
| Instance role | `nexora-ec2-ssm-role` with `AmazonSSMManagedInstanceCore` + `CloudWatchAgentServerPolicy` |
| PassRole | Restricted to the instance role ARN |
| Details | [iam-policies.md](../security/iam-policies.md) |

## 8. Systems Manager

| Component | Design |
|---|---|
| Access | Session Manager (shell, port forwarding), Fleet Manager (RDP in console) |
| Connectivity | Outbound HTTPS via public IPv4 + IGW |
| Logging | Session history; optional CloudWatch Logs |
| Details | [systems-manager.md](systems-manager.md) |

## 9. CloudWatch

| Component | Design |
|---|---|
| Metrics | Default EC2 metrics + agent memory/disk |
| Logs | Windows System/Security (selected), Linux syslog/auth, Nginx |
| Retention | 7–14 days (PROPOSED) |
| Alarms | Status check failed, CPU high |
| Detailed design | Day 06 — monitoring documentation is reserved for a later phase and is not part of this package |

## 10. S3

| Component | Design |
|---|---|
| Bucket | `nexora-tfstate-<account-id>-us-east-1` |
| Controls | Versioning, SSE, public access block, TLS-only policy, `prevent_destroy` |
| Locking | `use_lockfile = true` |
| Details | [terraform-state.md](terraform-state.md) |

## 11. Network Design

Summarised from [network-topology.md](../architecture/network-topology.md) and
[ip-addressing.md](../networking/ip-addressing.md):

| Element | Value |
|---|---|
| VPC | `nexora-vpc` 10.20.0.0/16 |
| Public subnet | `nexora-public-subnet-a` 10.20.1.0/24 |
| Private subnet | `nexora-private-subnet-a` 10.20.2.0/24 — reserved |
| Route | 0.0.0.0/0 → `nexora-igw` (public route table only) |
| Proposed IPs | NX-DC01 10.20.1.10, NX-LNX01 10.20.1.20 |
| SGs | `nexora-dc-sg`, `nexora-lnx-sg` |
| DHCP option set | `nexora-dhcp-options` after AD is healthy |

## 12. Deployment Sequence

Diagram source: [`infrastructure/diagrams/terraform-deployment-flow.mmd`](../../infrastructure/diagrams/terraform-deployment-flow.mmd)

| # | Step | Tool | Gate |
|---|---|---|---|
| 1 | Configure workstation tools and SSO profile | AWS CLI, Terraform | `aws sts get-caller-identity` works |
| 2 | Create budget alert | Console / CLI | Alert visible |
| 3 | Confirm region, AMIs and instance types | AWS CLI | Parameters resolve; types available |
| 4 | Bootstrap state bucket | Terraform (local state) | Bucket controls verified |
| 5 | Init main configuration with S3 backend | Terraform | Backend configured |
| 6 | Plan network + IAM + compute | Terraform | Plan reviewed and approved |
| 7 | Apply | Terraform | Instances running |
| 8 | Verify managed nodes | SSM | `PingStatus = Online` |
| 9 | Promote NX-DC01; handle `ssm-user` | PowerShell via SSM / Fleet Manager | `dcdiag` clean |
| 10 | Configure NX-LNX01 services | Bash via SSM | Services active |
| 11 | Apply DHCP option set and SG rules for AD traffic | Terraform | DNS tests pass |
| 12 | Monitoring, automation, tests | CloudWatch, scripts | Evidence collected |

## 13. Security

See [security-baseline.md](../security/security-baseline.md). Summary: no inbound admin ports,
least-privilege IAM, temporary credentials, encryption at rest and in transit, logging, patching.

## 14. Availability

| Aspect | Lab | Note |
|---|---|---|
| AZs | 1 | AZ failure = full outage (accepted) |
| DCs | 1 | DC failure = domain outage (accepted; restore from backup) |
| Instance recovery | EC2 auto-recovery / reboot on status-check failure (CloudWatch alarm action) — optional | VALIDATION REQUIRED |
| Data durability | EBS snapshots (stored regionally) | Day 07 |

## 15. Cost Optimisation

See [cost-management.md](cost-management.md). Key levers: stop when idle, no NAT Gateway, no
interface endpoints, no Elastic IPs, short log retention, right-sized volumes.

## 16. Limitations

- No high availability (single AZ, single DC).
- Public IPv4 per instance (outbound only) instead of private subnet + NAT/endpoints.
- Windows DHCP cannot serve EC2 instances.
- No client workstations for user-GPO validation.
- `nexora.local` conflicts with mDNS on macOS if resolved from workstations.
- Single AWS account (no Organizations / SCP guardrails).

## 17. Future Expansion

| Improvement | Uses |
|---|---|
| Move instances to `nexora-private-subnet-a` | NAT Gateway or VPC interface endpoints |
| Second DC in a second AZ (10.20.11.0/24) | AD and DNS redundancy |
| Site-to-site VPN (10.20.100.0/22 reserved) | Real hybrid scenario |
| Domain-join NX-LNX01 (SSSD/realmd) | Central Linux authentication |
| AWS Backup plans | Scheduled, policy-based backups |
| AWS Config / Security Hub | Compliance checks |
| Route 53 Resolver outbound endpoint | Let other VPCs resolve `nexora.local` |

## References

- AWS — Well-Architected Framework: <https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html>
- AWS — Amazon VPC User Guide: <https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html>
- AWS — Amazon EC2 Windows instances: <https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html>
- AWS — Public parameters for AMIs: <https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-public-parameters-ami.html>
- AWS — Systems Manager User Guide: <https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-systems-manager.html>
- Canonical — Find Ubuntu images on AWS: <https://documentation.ubuntu.com/aws/aws-how-to/instances/find-ubuntu-images/>
- Microsoft — AD DS deployment: <https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/ad-ds-deployment>
- HashiCorp — Terraform AWS provider: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs>
