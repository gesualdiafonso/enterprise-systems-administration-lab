# Implementation Guide

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | Implementation Guide |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | How to read, review, integrate and render this documentation package |

## 1. Purpose

This package contains **design documentation only**. "Implementation" here means integrating the
documents into the repository and using them as the reference for the hands-on phases
(Day 01–07). It does **not** mean deploying anything.

## 2. Recommended reading order

| # | Document | Why |
|---|---|---|
| 1 | [docs/project-brief.md](docs/project-brief.md) | Context, scope, roadmap |
| 2 | [docs/architecture/infrastructure-diagram.md](docs/architecture/infrastructure-diagram.md) | One-page map |
| 3 | [docs/architecture/aws-architecture.md](docs/architecture/aws-architecture.md) | AWS services and decisions |
| 4 | [docs/architecture/network-topology.md](docs/architecture/network-topology.md) | VPC layout |
| 5 | [docs/networking/ip-addressing.md](docs/networking/ip-addressing.md) | Address plan |
| 6 | [docs/networking/security-groups.md](docs/networking/security-groups.md) | Firewall rules |
| 7 | [docs/cloud/systems-manager.md](docs/cloud/systems-manager.md) | How administration works |
| 8 | [docs/security/iam-policies.md](docs/security/iam-policies.md) | Identities and permissions |
| 9 | [docs/cloud/terraform-state.md](docs/cloud/terraform-state.md) | IaC foundations |
| 10 | [docs/cloud/cost-management.md](docs/cloud/cost-management.md) | Before spending anything |
| 11 | [docs/networking/dns.md](docs/networking/dns.md), [dhcp.md](docs/networking/dhcp.md) | Name resolution and DHCP distinction |
| 12 | [docs/networking/domain-structure.md](docs/networking/domain-structure.md), [users-groups.md](docs/networking/users-groups.md), [gpo-policies.md](docs/networking/gpo-policies.md) | Active Directory (Day 02) |
| 13 | [docs/security/security-baseline.md](docs/security/security-baseline.md), [access-control.md](docs/security/access-control.md) | Security controls |
| 14 | [docs/cloud/aws-design.md](docs/cloud/aws-design.md) | Design rationale and deployment sequence |

## 3. Integration into the repository

Follow, in order:

1. [REPOSITORY-INTEGRATION/file-mapping.md](REPOSITORY-INTEGRATION/file-mapping.md) — destinations and conflicts.
2. [REPOSITORY-INTEGRATION/copy-procedures.md](REPOSITORY-INTEGRATION/copy-procedures.md) — safety check and copy (Windows and macOS).
3. [REPOSITORY-INTEGRATION/integration-checklist.md](REPOSITORY-INTEGRATION/integration-checklist.md) — tick-list.

Dependencies: Git and a local clone of the repository. Nothing else is required to integrate.

## 4. Rendering the diagrams

GitHub renders Mermaid code blocks in Markdown automatically, so every diagram is visible in the
`.md` files without extra tools.

The standalone `.mmd` files in `infrastructure/diagrams/` can be rendered to SVG/PNG with the
Mermaid CLI (**not installed by Claude**; requires Node.js and downloads a headless browser):

```bash
npx -p @mermaid-js/mermaid-cli mmdc -i infrastructure/diagrams/network-topology.mmd \
  -o infrastructure/diagrams/network-topology.svg
```

Alternatives: the Mermaid Live Editor (<https://mermaid.live>) or a Mermaid extension in VS Code.

## 5. How these documents are used in the next phases

| Phase | Primary documents |
|---|---|
| Day 01 | project-brief, cost-management, iam-policies (workstation auth), terraform-state (bootstrap) |
| Day 02 | domain-structure, users-groups, gpo-policies, dns, dhcp, systems-manager (§8 `ssm-user`) |
| Day 03 | security-baseline (Ubuntu), access-control (Linux) |
| Day 04 | security-groups, dns (§10), dhcp (option set), network-topology |
| Day 05 | aws-architecture, aws-design, terraform-state, iam-policies |
| Day 06 | aws-architecture (§8 CloudWatch), security-baseline (§10 logging) |
| Day 07 | Every validation table — fill with real results and evidence |

## 6. Updating the documents

- Change `Status` only when real evidence exists; never mark a document as validated without it.
- Replace `NOT TESTED` cells with the observed result and a link to the evidence file.
- Record changes in `CHANGELOG.md` and bump the version (1.0.1 for corrections, 1.1.0 for new
  content).

## 7. Items requiring human review

See [DOCUMENTATION-VALIDATION.md §4](DOCUMENTATION-VALIDATION.md#4-items-requiring-human-review).
