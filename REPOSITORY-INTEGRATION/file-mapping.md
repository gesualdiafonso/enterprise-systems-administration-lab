# File Mapping — Package → Repository

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | File Mapping |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | Where each package file goes in `gesualdiafonso/enterprise-systems-administration-lab` |

## 1. Repository inspected

| Item | Value |
|---|---|
| Repository | `https://github.com/gesualdiafonso/enterprise-systems-administration-lab` |
| Branch | `main` |
| Commit inspected | `832cc91` ("first commit") |
| Inspection method | Read-only shallow clone; nothing modified, committed or pushed |

## 2. Approved structure decisions

| Decision | Source |
|---|---|
| Keep the repository's **existing unnumbered folders** (`docs/architecture/`, `docs/networking/`, `docs/security/`) | Project owner, 2026-11-22 |
| Active Directory documents stay in `docs/networking/` (their current location) | Project owner — keep repository structure |
| New cloud documents go to a new folder `docs/cloud/` | Follows the unnumbered convention |
| **Correct three filenames**; flag the old ones in this guide | Project owner — "Corrigir os nomes" |
| No `git mv` / `git rm` commands in the integration guide | Project owner |

## 3. Mapping table

Legend for **Repository state**: `EMPTY` = file exists with 0 bytes · `ABSENT` = file does not exist.

| Package path | Repository destination | Repository state | Action |
|---|---|---|---|
| `docs/project-brief.md` | `docs/project-brief.md` | EMPTY | Add or review — replaces empty file |
| `docs/architecture/aws-architecture.md` | `docs/architecture/aws-architecture.md` | EMPTY | Add or review — replaces empty file |
| `docs/architecture/network-topology.md` | `docs/architecture/network-topology.md` | EMPTY | Add or review — replaces empty file |
| `docs/architecture/infrastructure-diagram.md` | `docs/architecture/infrastructure-diagram.md` | ABSENT | Add — **corrected name** (see §4) |
| `docs/networking/domain-structure.md` | `docs/networking/domain-structure.md` | EMPTY | Add or review — replaces empty file |
| `docs/networking/gpo-policies.md` | `docs/networking/gpo-policies.md` | EMPTY | Add or review — replaces empty file |
| `docs/networking/users-groups.md` | `docs/networking/users-groups.md` | ABSENT | Add — **corrected name** (see §4) |
| `docs/networking/ip-addressing.md` | `docs/networking/ip-addressing.md` | ABSENT | Add |
| `docs/networking/dns.md` | `docs/networking/dns.md` | ABSENT | Add |
| `docs/networking/dhcp.md` | `docs/networking/dhcp.md` | ABSENT | Add |
| `docs/networking/security-groups.md` | `docs/networking/security-groups.md` | ABSENT | Add |
| `docs/security/security-baseline.md` | `docs/security/security-baseline.md` | ABSENT | Add — **corrected name** (see §4) |
| `docs/security/access-control.md` | `docs/security/access-control.md` | ABSENT | Add |
| `docs/security/iam-policies.md` | `docs/security/iam-policies.md` | ABSENT | Add |
| `docs/cloud/aws-design.md` | `docs/cloud/aws-design.md` | ABSENT (folder absent) | Add — creates `docs/cloud/` |
| `docs/cloud/cost-management.md` | `docs/cloud/cost-management.md` | ABSENT | Add |
| `docs/cloud/systems-manager.md` | `docs/cloud/systems-manager.md` | ABSENT | Add |
| `docs/cloud/terraform-state.md` | `docs/cloud/terraform-state.md` | ABSENT | Add |
| `infrastructure/diagrams/*.mmd` (5 files) | `infrastructure/diagrams/` | ABSENT (folder absent) | Add — creates `infrastructure/diagrams/` |

Package-only files (**not** copied to the repository): `README.md`, `CHANGELOG.md`,
`FILE-INDEX.md`, `IMPLEMENTATION-GUIDE.md`, `DOCUMENTATION-VALIDATION.md`, `REPOSITORY-INTEGRATION/`.

## 4. Conflicts and superseded files

No file with **content** is overwritten: every existing destination is a 0-byte file.

| Existing repository file | Size | Replaced by (package) | Conflict type | Proposed resolution |
|---|---|---|---|---|
| `docs/architecture/infrastructure-diagrama.md` | 0 B | `docs/architecture/infrastructure-diagram.md` | Misspelled name (Portuguese "diagrama") | Old file becomes **superseded**; owner decides whether to delete it |
| `docs/networking/user-groups.md` | 0 B | `docs/networking/users-groups.md` | Name differs from approved spec | Old file **superseded**; owner decides |
| `docs/security/secutiry-baseline.md` | 0 B | `docs/security/security-baseline.md` | Typo ("secutiry") | Old file **superseded**; owner decides |

If the superseded files are kept, the repository will contain two files per topic (one empty).
Removing them is recommended but is left to the owner, as agreed.

## 5. Repository issues outside this package's scope (not changed)

| File | Observation | Recommendation |
|---|---|---|
| `claude.md` | Content ends abruptly at line 264 ("Do not") — **truncated** | Restore the full text. Consider renaming to `CLAUDE.md` (Claude Code looks for this exact name; case matters on Linux) |
| `.gitignore` | Empty (0 B) | Populate **before** any Terraform or credentials work (patterns in [`docs/cloud/terraform-state.md`](../docs/cloud/terraform-state.md#12-gitignore-rules)) |
| `install.cmd` | The Claude Code Windows installer script, unrelated to the project | Remove from the repository |
| `README.md` | Empty | Write the project README (future task) |
| `LICENSE` | Empty | Choose and add a licence text (future task) |
