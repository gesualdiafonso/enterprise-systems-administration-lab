# ESAL Documentation Foundation — v1.0.0

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Package** | ESAL-DOCUMENTATION-FOUNDATION-v1.0.0 |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | Initial technical documentation and architecture diagrams — documentation only |

## What this package is

The documentation foundation for the Enterprise Systems Administration Lab: 18 Markdown documents
and 5 Mermaid diagram sources describing the **proposed** AWS architecture for Nexora Technologies
(NX-DC01 Windows Server 2022 Domain Controller and NX-LNX01 Ubuntu 24.04 server, administered
through AWS Systems Manager and provisioned with Terraform).

## What this package is not

- **No AWS resource was created.** No Terraform was run. No EC2 instance exists.
- No implementation scripts (PowerShell, Bash, Python) are included.
- No monitoring, runbook or final-report documentation (reserved for later phases).
- No evidence, screenshots or test results — every validation table is `NOT TESTED`.

## Contents

```text
ESAL-DOCUMENTATION-FOUNDATION-v1.0.0/
├── README.md                     ← this file
├── CHANGELOG.md
├── FILE-INDEX.md                 ← inventory of every file
├── IMPLEMENTATION-GUIDE.md       ← how to read, review and use the package
├── DOCUMENTATION-VALIDATION.md   ← QA checklist with actual outcomes
├── docs/                         ← mirrors the repository's docs/ structure
│   ├── project-brief.md
│   ├── architecture/   (3 files)
│   ├── networking/     (7 files: networking + Active Directory)
│   ├── security/       (3 files)
│   └── cloud/          (4 files)
├── infrastructure/
│   └── diagrams/       (5 .mmd files)
└── REPOSITORY-INTEGRATION/
    ├── file-mapping.md
    ├── copy-procedures.md
    └── integration-checklist.md
```

The `docs/` tree follows the repository's **existing unnumbered folders**, as decided by the
project owner. Three filenames were corrected (see [CHANGELOG.md](CHANGELOG.md)).

## Start here

1. [DOCUMENTATION-VALIDATION.md](DOCUMENTATION-VALIDATION.md) — what was checked and how.
2. [docs/project-brief.md](docs/project-brief.md) — project overview.
3. [REPOSITORY-INTEGRATION/file-mapping.md](REPOSITORY-INTEGRATION/file-mapping.md) — where files go and which conflicts exist.
4. [REPOSITORY-INTEGRATION/copy-procedures.md](REPOSITORY-INTEGRATION/copy-procedures.md) — safe copy commands.

## Key architecture facts (all PROPOSED)

| Item | Value |
|---|---|
| Region | `us-east-1` — initial target, VALIDATION REQUIRED |
| VPC | `nexora-vpc` 10.20.0.0/16 |
| Public subnet | 10.20.1.0/24 (both instances) |
| Private subnet | 10.20.2.0/24 (reserved, not deployed) |
| Domain | `nexora.local` |
| Admin access | AWS Systems Manager only — no inbound 22/3389 |
| IaC | Terraform ≥ 1.11, S3 backend with `use_lockfile = true` (no DynamoDB) |
| Departments | Management, Administration, IT, Finance, Human Resources, Operations (15 fictional users) |
