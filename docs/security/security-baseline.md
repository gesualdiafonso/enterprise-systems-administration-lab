# Security Baseline

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | Security Baseline |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | Security objectives, shared responsibility, AWS, Windows, Ubuntu, network, encryption, patching, logging, backup, checklist |

> **Status:** Baseline is **PROPOSED**. No control has been implemented or tested.

---

## 1. Security Objectives

| ID | Objective |
|---|---|
| SO-1 | No administrative service is reachable from the Internet. |
| SO-2 | Every human and workload identity has only the permissions it needs. |
| SO-3 | No long-lived secret is stored in code, repositories or evidence. |
| SO-4 | Data at rest (EBS, S3) and in transit (AWS APIs, SSM) is encrypted. |
| SO-5 | Security-relevant events are logged and retained for the lab's duration. |
| SO-6 | Systems are patched on a defined cadence. |
| SO-7 | The environment can be restored from documented backups. |

## 2. Shared Responsibility Model

| AWS is responsible for ("security **of** the cloud") | The project is responsible for ("security **in** the cloud") |
|---|---|
| Physical data centres, hardware, hypervisor | Guest OS patching (Windows, Ubuntu) |
| Global network infrastructure | Security Group and NACL configuration |
| Managed service infrastructure (SSM, S3, CloudWatch) | IAM users, roles and policies |
| | Application configuration (AD, Nginx, MariaDB) |
| | Data encryption choices and key management |
| | Backups and recovery testing |

## 3. AWS Security Fundamentals

| Control | Implementation | Status |
|---|---|---|
| Root user protection | MFA enabled, no access keys, used only for account-level tasks | PLANNED |
| Human access | IAM Identity Center with temporary credentials | PROPOSED |
| Workload access | EC2 instance profile (`nexora-ec2-ssm-role`) | PROPOSED |
| API auditing | AWS CloudTrail event history (enabled by default, 90 days); a trail to S3 is optional | PROPOSED |
| IMDSv2 | Required on both instances | PROPOSED |
| Tagging | `Project=ESAL` on all resources for visibility | PROPOSED |
| Cost alerts | AWS Budgets (alerts only) | PLANNED |

## 4. Windows Server Security (NX-DC01)

| Area | Control | Status |
|---|---|---|
| Accounts | Separate `adm-` accounts; built-in Administrator break-glass only | PROPOSED |
| Password/lockout | Domain policy per [gpo-policies.md](../networking/gpo-policies.md) | PROPOSED |
| Auditing | Advanced audit policy on DCs | PROPOSED |
| Protocols | SMBv1 disabled; LDAP signing reviewed | PROPOSED |
| Services | Only AD DS, DNS, (DHCP educational) and required agents | PROPOSED |
| Defender | Microsoft Defender Antivirus enabled with current signatures | PROPOSED |
| Remote access | No RDP from Internet; Fleet Manager / port forwarding only | PROPOSED |
| Baseline reference | Microsoft Security Baselines (Security Compliance Toolkit) for review | PROPOSED |

## 5. Ubuntu Server Security (NX-LNX01)

| Area | Control | Status |
|---|---|---|
| Access | Session Manager; no inbound SSH; no key pair at launch | PROPOSED |
| Privilege | Named sudo users via groups; `ssm-user` sudo rights reviewed | PROPOSED |
| Host firewall | UFW: default deny incoming, allow outgoing; allow 80/tcp only from 10.20.1.10 | PROPOSED |
| Brute-force mitigation | Fail2ban (Nginx jails; sshd jail only if SSH is ever enabled internally) | PROPOSED |
| Updates | `unattended-upgrades` for security updates | PROPOSED |
| Services | Nginx (`server_tokens off`), MariaDB bound to 127.0.0.1, `mariadb-secure-installation` | PROPOSED |
| File permissions | Configuration files owned by root, least-permissive modes | PROPOSED |

> **Note on Fail2ban:** with no SSH exposed, Fail2ban's classic SSH protection has little to do.
> Its value here is educational and for Nginx log-based jails (e.g. repeated 4xx/auth failures).

## 6. Network Security

| Layer | Control |
|---|---|
| VPC | Private address space 10.20.0.0/16 |
| Routing | Only the public subnet routes to the Internet Gateway |
| Security Groups | No world-open inbound rules; SG-to-SG references ([security-groups.md](../networking/security-groups.md)) |
| Host firewall | Windows Defender Firewall / UFW |
| Service binding | MariaDB on localhost only |

## 7. Encryption

| Data | At rest | In transit |
|---|---|---|
| EBS volumes | EBS encryption (AWS managed key `aws/ebs` or a KMS key) | — |
| Terraform state | S3 SSE (SSE-S3 or SSE-KMS) | HTTPS enforced by bucket policy |
| SSM sessions | — | TLS 1.2+; optional additional KMS encryption of session data |
| CloudWatch Logs | Encrypted by default; optional KMS key | HTTPS |
| Web traffic (Nginx) | — | HTTP inside VPC for the lab; TLS with a private CA is a future improvement |

## 8. Patch Management

| System | Method | Cadence (proposed) |
|---|---|---|
| Windows Server | Windows Update or SSM Patch Manager (`AWS-RunPatchBaseline`) | Weekly during active lab days |
| Ubuntu | `unattended-upgrades` + `apt` / SSM Patch Manager | Security updates daily (automatic) |
| SSM Agent | Auto-update via SSM (optional) or Run Command | Monthly |
| Terraform providers | Pinned with `~>`; reviewed per phase | Per phase |

## 9. Firewall Summary

| Firewall | Default inbound | Allowed inbound (proposed) |
|---|---|---|
| `nexora-dc-sg` | Deny | AD/DNS ports from `nexora-lnx-sg` |
| `nexora-lnx-sg` | Deny | TCP 80 from `nexora-dc-sg` |
| Windows Defender Firewall (DC) | Block | Default AD DS/DNS rules |
| UFW (Linux) | Deny | 80/tcp from 10.20.1.10 |

## 10. Logging

| Source | Destination | Retention (proposed) | Status |
|---|---|---|---|
| AWS API calls | CloudTrail event history | 90 days (AWS default) | Available by default |
| SSM session history | Systems Manager console | Service default | Available by default |
| SSM session output (optional) | CloudWatch Logs `/nexora/ssm/sessions` | 7–14 days | PLANNED |
| Windows Security / System logs | CloudWatch Logs via agent | 7–14 days | PLANNED (Day 06) |
| Linux syslog, auth, Nginx, Fail2ban | CloudWatch Logs via agent | 7–14 days | PLANNED (Day 06) |

## 11. Backup

| Asset | Method | Status |
|---|---|---|
| NX-DC01 | AD System State backup + EBS snapshot | PLANNED (Day 07) |
| NX-LNX01 | EBS snapshot; `mariadb-dump` of databases | PLANNED (Day 07) |
| Terraform state | S3 versioning | PROPOSED |
| Code and docs | GitHub repository | In place (repository exists) |

A backup is valid only after a **restore test** succeeds.

## 12. Incident Prevention

- Least privilege everywhere (IAM, AD, sudo).
- No secrets in Git: `.gitignore`, GitHub secret scanning / push protection.
- Instances stopped when idle (smaller exposure window and cost).
- Regular review of SG rules, IAM permissions and privileged AD groups.
- Evidence sanitised: AWS account IDs masked, no personal data.

## 13. Security Checklist

| ID | Control | Owner | Status |
|---|---|---|---|
| SEC-01 | Root MFA enabled, no root access keys | Author | NOT TESTED |
| SEC-02 | Daily work through IAM Identity Center | Author | NOT TESTED |
| SEC-03 | No SG inbound rule from 0.0.0.0/0 or ::/0 | Terraform | NOT TESTED |
| SEC-04 | No key pair on instances | Terraform | NOT TESTED |
| SEC-05 | IMDSv2 required | Terraform | NOT TESTED |
| SEC-06 | EBS encryption enabled | Terraform | NOT TESTED |
| SEC-07 | State bucket: versioning, encryption, public access block, TLS-only | Bootstrap | NOT TESTED |
| SEC-08 | Instance role limited to SSM + CloudWatch agent policies | Terraform | NOT TESTED |
| SEC-09 | Domain password/lockout policy applied | AD | NOT TESTED |
| SEC-10 | Advanced auditing on DC | AD | NOT TESTED |
| SEC-11 | UFW active with default deny | Linux | NOT TESTED |
| SEC-12 | MariaDB bound to 127.0.0.1 | Linux | NOT TESTED |
| SEC-13 | `.gitignore` protects state, tfvars, keys, `.env` | Repository | **Gap identified** — repository `.gitignore` is currently empty |
| SEC-14 | Budget alert configured | Author | NOT TESTED |

## References

- AWS — Shared Responsibility Model: <https://aws.amazon.com/compliance/shared-responsibility-model/>
- AWS — Security pillar, Well-Architected: <https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html>
- AWS — Amazon EBS encryption: <https://docs.aws.amazon.com/ebs/latest/userguide/ebs-encryption.html>
- AWS — Systems Manager Patch Manager: <https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager.html>
- AWS — CloudTrail event history: <https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html>
- Microsoft — Windows security baselines: <https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/windows-security-baselines>
- Ubuntu — Server documentation (security, firewall, automatic updates): <https://documentation.ubuntu.com/server/>
- Fail2ban — Project documentation: <https://github.com/fail2ban/fail2ban>
