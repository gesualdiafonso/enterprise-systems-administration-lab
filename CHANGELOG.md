# Changelog

All notable changes to the ESAL documentation package are recorded here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-11-22

### Added

- `docs/project-brief.md` — executive summary, scope, roadmap, acceptance criteria, risks.
- `docs/architecture/` — `infrastructure-diagram.md`, `network-topology.md`, `aws-architecture.md`.
- `docs/networking/` — `ip-addressing.md`, `dns.md`, `dhcp.md`, `security-groups.md`.
- `docs/networking/` (Active Directory) — `domain-structure.md`, `users-groups.md`, `gpo-policies.md`.
- `docs/security/` — `security-baseline.md`, `access-control.md`, `iam-policies.md`.
- `docs/cloud/` (new folder) — `aws-design.md`, `cost-management.md`, `systems-manager.md`, `terraform-state.md`.
- `infrastructure/diagrams/` (new folder) — five Mermaid sources.
- Package files: README, CHANGELOG, FILE-INDEX, IMPLEMENTATION-GUIDE, DOCUMENTATION-VALIDATION,
  REPOSITORY-INTEGRATION guides.

### Changed (relative to the repository at commit `832cc91`)

- Filled five previously empty files: `project-brief.md`, `aws-architecture.md`,
  `network-topology.md`, `domain-structure.md`, `gpo-policies.md`.
- **Corrected filenames** (new files; old empty files left in place for the owner to decide):
  - `infrastructure-diagrama.md` → `infrastructure-diagram.md`
  - `user-groups.md` → `users-groups.md`
  - `secutiry-baseline.md` → `security-baseline.md`

### Decisions recorded

- Repository's unnumbered folder structure kept; AD documents remain in `docs/networking/`.
- Six departments: Management, Administration, IT, Finance, Human Resources, Operations
  (15 fictional users; earlier planning had 13 users in five departments).
- Domain `nexora.local` kept as approved; mDNS/macOS trade-off documented.
- Terraform ≥ 1.11 with native S3 locking; DynamoDB not used.

### Not included (by scope)

- Monitoring, runbooks and final report documentation.
- Implementation scripts, Terraform code, evidence.
