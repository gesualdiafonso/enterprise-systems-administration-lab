# PowerShell automation - NX-DC01 / nexora.local

Scripts that build and administer the Domain Controller **NX-DC01**. They run **on the instance**
as `SYSTEM` through **AWS Systems Manager Run Command**. They are launched from the workstation;
no RDP, WinRM or SSH port is opened.

> Status: written and checked offline (Bash syntax, gzip/base64 payload round-trip, ASCII-only). **Not yet executed
> on AWS.** PowerShell syntax has not been analysed with PSScriptAnalyzer yet.

## Layout

```text
automation/
├── aws-cli/
│   ├── set-lab-secrets.sh      # stores lab passwords in SSM Parameter Store (SecureString)
│   ├── run-dc-script.sh        # copies lib + config + script to C:\Nexora and runs it via SSM
│   └── day02-preflight.sh      # read-only checks before creating NX-DC01
└── powershell/
    ├── config/nexora-ad.psd1   # single source of truth: domain, OUs, groups, users (fictional), DNS, GPO values
    ├── lib/NexoraLab.psm1      # logging, config, SSM secrets, AD wait helpers
    └── scripts/                # 01-09 build steps (idempotent), 20-25 read-only reports
```

## Secrets

No password is written in Git, Terraform or the scripts. They live in SSM Parameter Store as
`SecureString` values and are read on the DC with the instance role (`AmazonSSMManagedInstanceCore`
allows `ssm:GetParameter`; the AWS managed key `aws/ssm` allows decryption through SSM).

| Parameter | Used by | Purpose |
|---|---|---|
| `/nexora/windows/administrator-password` | 01 | Built-in Administrator (break-glass; becomes `NEXORA\Administrator`) |
| `/nexora/ad/dsrm-password` | 02 | Directory Services Restore Mode |
| `/nexora/ad/initial-user-password` | 05 | Initial password of standard users (must change at logon) |
| `/nexora/ad/admin-account-password` | 05 | `adm-` accounts (Fleet Manager logon) |

```bash
./automation/aws-cli/set-lab-secrets.sh          # hidden input, skips existing values
```

## Run order (Day 02)

| # | Command (from the repository root) | Tasks | Reboot |
|---|---|---|---|
| 0 | `terraform apply` with `create_dc = true` | WIN-001..007 | - |
| 1 | `./automation/aws-cli/run-dc-script.sh 01-Set-ServerBaseline.ps1` | Part B: IP check, time zone, Administrator password, firewall, Server Manager, hostname | Yes (rename) |
| 2 | Windows Update via `AWS-InstallWindowsUpdates` (below) | Part B: updates | Possibly |
| 3 | `./automation/aws-cli/run-dc-script.sh 02-Install-ADDSForest.ps1` | AD-001..003, DNS forwarder, time sync, `ssm-user` | Yes (promotion) |
| 4 | `./automation/aws-cli/run-dc-script.sh 03-New-ADOrganizationalUnits.ps1` | AD-004 | - |
| 5 | `./automation/aws-cli/run-dc-script.sh 04-New-ADGroups.ps1` | AD-006 (AGDLP nesting) | - |
| 6 | `./automation/aws-cli/run-dc-script.sh 05-New-ADUsers.ps1` | AD-005, `adm-` accounts | - |
| 7 | `./automation/aws-cli/run-dc-script.sh 06-New-ADServiceAccounts.ps1` | AD-007 | - |
| 8 | `./automation/aws-cli/run-dc-script.sh 07-Set-ADDelegation.ps1` | AD-008 (help-desk delegation) | - |
| 9 | `./automation/aws-cli/run-dc-script.sh 08-Set-DnsConfiguration.ps1` | DNS-001..004: zones, reverse zone, A/CNAME/PTR, forwarders | - |
| 10 | `./automation/aws-cli/run-dc-script.sh 09-Set-GroupPolicies.ps1` | GPO-001..005 (table below) | - |
| 11 | `terraform apply` with `enable_ad_dhcp_options = true` | DHCP-001..003 (only after 24-Test-NxDns passes) | Renew leases |

## Query and report scripts (Part F, read-only)

| Script | Purpose | Useful arguments |
|---|---|---|
| `20-Get-NxUsers.ps1` | Users, state, groups; acceptance checks (15 users, Domain Admins, `CN=Users`) | `-Department Finance`, `-Identity mgomes` |
| `21-Get-NxGroups.ps1` | Groups, scope, nesting, effective members; privileged groups | `-Name DL-FS-Finance-RW` |
| `22-Get-NxDomainHealth.ps1` | **AD-009** health report: services, SYSVOL, dcdiag, SRV, time, event errors | `-EventHours 48` |
| `23-Get-NxGpoReport.ps1` | **GPO-006** evidence: links, policies in force, auditpol, firewall, gpresult; HTML reports | - |
| `24-Test-NxDns.ps1` | Zones, forwarders, DNS client, PASS/FAIL resolution tests | - |
| `25-Export-NxADInventory.ps1` | CSV + JSON inventory of OUs, users, groups, memberships, GPOs, DNS | - |

Reports are written to `C:\Nexora\reports\<yyyyMMdd>\` on NX-DC01 (open them through Fleet Manager).

## Group Policy implemented by `09`

| GPO | Linked to | Settings |
|---|---|---|
| Default Domain Policy (edited) | `nexora.local` | Password: min 14, complexity, history 24, min age 1, no max age. Lockout: 10 attempts / 15 min |
| FGPP `NX-PSO-Admins` | `GG-Admin-Accounts` | Min 16, lockout 5 / 30 min, max age 365 days |
| `NX-DC-Audit-Policy` | `OU=Domain Controllers` | Advanced audit (8 subcategories), subcategory override, Security log 512 MB |
| `NX-Baseline-Security` | `OU=Nexora` (Enforced) + `OU=Domain Controllers` | Firewall on/Block inbound/log drops, SMBv1 off, logon banner |
| `NX-Servers-Admins` | `OU=Servers` | `GG-IT-ServerAdmins` added to local Administrators (Restricted Groups, MemberOf) |
| `NX-ServiceAccounts-Restrictions` | `OU=Domain Controllers` + `OU=Servers` | `GG-Service-Accounts` denied local and RDP logon |
| `NX-Users-Desktop` | Department OUs | Password-protected screen saver after 15 min |

Deviations from `docs/networking/gpo-policies.md`:

- `NX-Baseline-Security` is also linked to `OU=Domain Controllers`. There are no member computers yet,
  so the DC is the only machine that can produce evidence (`gpresult`).
- `NX-ServiceAccounts-Restrictions` is linked to **computer** OUs. User Rights Assignment is a computer
  setting; linked to `OU=Service Accounts`, which contains only users, it would never apply.
- Maximum password age: **0 (no forced expiry)**, following the Microsoft security baseline and NIST
  SP 800-63B. Privileged `adm-` accounts still expire after 365 days through the FGPP.

Windows Update (AWS-managed document):

```bash
aws ssm send-command --region us-east-1 --document-name AWS-InstallWindowsUpdates \
  --instance-ids <instance-id> --parameters 'Action=Install,AllowReboot=True' \
  --comment "ESAL Windows Update"
```

`DRY_RUN=1 ./automation/aws-cli/run-dc-script.sh <script>` prints the SSM parameters without calling AWS.

## How reboots work

A script that needs a reboot exits with code **3010**. The SSM Agent then reboots the instance
and **runs the same command again**. Every script is idempotent: on the second run it finds the
work already done and continues. `run-dc-script.sh` keeps waiting through the reboot.

## Design notes

- **DNS and SSM after promotion.** Once NX-DC01 is a DC it resolves names with its own DNS server.
  `02` sets the VPC resolver `10.20.0.2` as forwarder *before* rebooting. `nexora-dc-sg` also allows
  outbound DNS so root hints work as a fallback. Without this the SSM Agent could not resolve its
  endpoints and the instance would become unreachable.
- **`ssm-user` is a Domain Admin.** AWS requires this for Session Manager on domain controllers.
  It is a documented exception (`docs/cloud/systems-manager.md` section 8) and stays in `CN=Users`.
- **Service accounts** get a random 48-character password that nobody sees. It is reset when a real
  service is configured.
- **All people in `nexora-ad.psd1` are fictional.**
