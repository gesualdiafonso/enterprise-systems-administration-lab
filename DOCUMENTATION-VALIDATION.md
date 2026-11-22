# Documentation Validation

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | Documentation Validation |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | Quality checks performed on this package before delivery, with actual outcomes |

> These checks validate the **documentation**, not the infrastructure. No infrastructure test was
> performed because nothing is deployed.

## 1. Validation checklist

| # | Check | Method actually used | Outcome |
|---|---|---|---|
| 1 | Every required Markdown file exists | Scripted existence + non-empty check of the 18 required documents | **PASS** — 18/18 |
| 2 | Every required Mermaid diagram exists | Same script for the 5 `.mmd` files | **PASS** — 5/5 |
| 3 | Internal relative links resolve | Python script: resolves every relative Markdown link, including `#anchor` fragments against GitHub-style heading slugs | **PASS** — 54 links in `docs/`, 0 broken (re-run after package files were added: see §2) |
| 4 | Mermaid syntax valid | `mermaid.parse()` from the official `mermaid` npm package v11.17.2 (jsdom), installed in a scratch folder only — no global install. Negative test with two broken diagrams confirmed the parser rejects invalid syntax | **PASS** — 20/20 diagrams (5 `.mmd` + 15 embedded blocks). **Rendering to SVG/PNG was NOT performed** (Mermaid CLI not installed) |
| 5 | Terminology consistent | `grep` inventory of resource names, domain names, IPs, Terraform version | **PASS** — 11 resource names used consistently; one domain (`nexora.local`); IPs consistent (DC 10.20.1.10, LNX 10.20.1.20, resolver 10.20.0.2); Terraform ≥ 1.11 everywhere |
| 6 | AWS architecture consistent across documents | Same inventory + manual review of VPC/subnet/SG/IAM names in each document | **PASS** |
| 7 | No claim that infrastructure is deployed | `grep` for "successfully deployed/created/configured/tested", "has been deployed/validated", "Status: Passed/Validated" | **PASS** — 1 match, which is an *expected* `terraform init` output shown in a code comment |
| 8 | No public inbound administrative access recommended | `grep` for lines containing port 22/3389 and `0.0.0.0/0` | **PASS** — 3 matches, all in prohibition statements/tables |
| 9 | DHCP distinction correct | Manual review of `dhcp.md` + `grep` of every "Windows DHCP" mention | **PASS** — all mentions state it is educational and does not serve EC2 |
| 10 | S3 native locking documented correctly | `grep` for `DynamoDB` and `use_lockfile`; facts checked against HashiCorp v1.11 upgrade guide (via web search) | **PASS** — DynamoDB only mentioned as "not used / deprecated"; `use_lockfile = true` in backend examples |
| 11 | No credentials or sensitive values | `grep` for AWS key patterns (`AKIA`, `ASIA`), private-key headers, `aws_secret_access_key`, hard-coded passwords, 12-digit account IDs | **PASS** — only `111122223333` (AWS documentation placeholder account) |
| 12 | Excluded directories not generated/modified | `find` for monitoring/runbooks/final-report folders in the package; repository clone left untouched | **PASS** — none in package; repository not modified (no commit, no push) |
| 13 | ZIP contains the complete requested structure | `unzip -l` listing compared with the requested tree; extraction test | Recorded in §3 |

## 2. Additional checks

| Check | Method | Outcome |
|---|---|---|
| Metadata header in every `docs/` document (Project, Document, Version, Status, Last updated, Scope) | Scripted `grep` | **PASS** — 18/18 |
| `Status: DRAFT / PROPOSED` in every `docs/` document | Scripted `grep` | **PASS** — 18/18 |
| `References` section in every `docs/` document | Scripted `grep` | **PASS** — 18/18 |
| External reference URLs | 101 unique URLs. 27 were fetched individually; 26 resolved to the expected page; 1 failed (MS16-072 article) and was **replaced** with a Microsoft Learn URL found through web search. 1 Canonical URL redirected and was replaced with the canonical "Find Ubuntu images on AWS" page. A few more were confirmed indirectly through search results. | **PARTIAL** — about 70 URLs were **not individually verified** (the workspace cannot reach the Internet directly) |
| SSM public parameter paths | Windows path pattern confirmed on the AWS public-parameters page; Ubuntu path confirmed on Canonical documentation | **PASS** (path format); availability in the target region still **VALIDATION REQUIRED** |
| AWS subnet reserved addresses | Checked against the AWS "Subnet CIDR blocks" page | **PASS** |
| `ssm-user` on domain controllers | Checked against AWS SSM Agent technical details / Session Manager prerequisites | **PASS** |
| Copy procedure (bash) | Executed against a **throwaway copy** of the repository clone: 5 EMPTY + 18 ABSENT detected; 23 files copied; `git status` = 5 modified + 18 untracked; second run skipped all 23 (no overwrite) | **PASS** |
| Copy procedure (PowerShell) | Not executed — PowerShell is not available in the build environment | **NOT TESTED** |

## 3. Package verification

| Check | Outcome |
|---|---|
| ZIP file name | `ESAL-DOCUMENTATION-FOUNDATION-v1.0.0.zip` |
| Root folder | `ESAL-DOCUMENTATION-FOUNDATION-v1.0.0/` |
| Extraction test | Performed after packaging — see the delivery report (results are recorded there because they cannot be written into the archive they describe) |

## 4. Items requiring human review

| # | Item | Document |
|---|---|---|
| 1 | Finance + Management: six departments, 15 fictional users and their names | [users-groups.md](docs/networking/users-groups.md) |
| 2 | Maximum password age decision (no expiry vs 365 days) | [gpo-policies.md §6](docs/networking/gpo-policies.md#6-password-policy) |
| 3 | DHCP option set DNS fallback strategy (Day 04) | [dns.md §10](docs/networking/dns.md#10-relationship-with-the-dhcp-option-set) |
| 4 | Candidate instance types (`t3.medium`, `t3.small`) and volume sizes | [aws-architecture.md §5](docs/architecture/aws-architecture.md#5-amazon-ec2) |
| 5 | `ssm-user` as a Domain Admin on NX-DC01 — accept the risk and controls | [systems-manager.md §8](docs/cloud/systems-manager.md#8-domain-controller-consideration-ssm-user) |
| 6 | Session-ARN pattern in the illustrative Session Manager policy | [iam-policies.md §10.3](docs/security/iam-policies.md#103-session-manager-limited-to-esal-tagged-instances) |
| 7 | Fleet Manager IAM permissions for the user (to confirm in AWS docs) | [systems-manager.md §3](docs/cloud/systems-manager.md#3-fleet-manager) |
| 8 | Budget amount | [cost-management.md §11](docs/cloud/cost-management.md#11-aws-budgets) |
| 9 | Superseded empty files in the repository (keep/delete) | [file-mapping.md §4](REPOSITORY-INTEGRATION/file-mapping.md#4-conflicts-and-superseded-files) |
| 10 | Placement of AD documents in `docs/networking/` (owner decision, recorded) | [file-mapping.md §2](REPOSITORY-INTEGRATION/file-mapping.md#2-approved-structure-decisions) |

## 5. Known limitations of this validation

- Mermaid diagrams were **parsed**, not **rendered**; visual layout should be checked in GitHub preview.
- Around 70 external links were not individually fetched.
- Technical accuracy was reviewed by the author of the documents, not by an independent reviewer.
- PowerShell commands in the documents are illustrative and were not executed.
