# Integration Checklist

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | Integration Checklist |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | Steps for the owner to tick while integrating the package |

## Before copying

- [ ] ZIP extracted; folder `ESAL-DOCUMENTATION-FOUNDATION-v1.0.0/` present.
- [ ] Read `README.md` and `DOCUMENTATION-VALIDATION.md` of the package.
- [ ] Repository clone up to date (`git pull`), working tree clean.
- [ ] Integration branch created (recommended).
- [ ] Safety check run ([copy-procedures.md §2](copy-procedures.md#2-safety-check--destinations-must-be-empty-or-absent)): 0 × `HAS CONTENT`.

## Copy

- [ ] Copy procedure run ([copy-procedures.md §3](copy-procedures.md#3-copy)).
- [ ] `git status` shows 5 modified + 18 new files.
- [ ] `docs/cloud/` and `infrastructure/diagrams/` exist.

## Review (human)

- [ ] Departments and 15 fictional users are acceptable ([users-groups.md](../docs/networking/users-groups.md)).
- [ ] Proposed IPs 10.20.1.10 / 10.20.1.20 accepted.
- [ ] Proposed resource names (`nexora-vpc`, `nexora-dc-sg`, …) accepted.
- [ ] `nexora.local` trade-off acknowledged ([domain-structure.md](../docs/networking/domain-structure.md#5-domain-name--nexoralocal)).
- [ ] Password policy decision on maximum password age ([gpo-policies.md](../docs/networking/gpo-policies.md#6-password-policy)).
- [ ] DHCP option set fallback strategy to be decided on Day 04 ([dns.md](../docs/networking/dns.md#10-relationship-with-the-dhcp-option-set)).
- [ ] Mermaid diagrams render correctly in GitHub preview.

## Superseded files (owner's decision)

- [ ] `docs/architecture/infrastructure-diagrama.md` — keep or delete.
- [ ] `docs/networking/user-groups.md` — keep or delete.
- [ ] `docs/security/secutiry-baseline.md` — keep or delete.

## Out-of-scope repository fixes (recommended, separate commits)

- [ ] Restore full `claude.md` (truncated) and consider renaming to `CLAUDE.md`.
- [ ] Populate `.gitignore` before any Terraform work.
- [ ] Remove `install.cmd` (Claude Code installer, not project content).
- [ ] Write `README.md`; add `LICENSE` text.

## Close

- [ ] Commit created by the owner.
- [ ] Branch pushed / merged by the owner.
- [ ] Package version `1.0.0` recorded as integrated.
