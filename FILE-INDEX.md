# File Index

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | File Index |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | Inventory of every file in the package |

Dependencies: Markdown files depend only on each other (relative links) and on the `.mmd` sources
for diagram links. `.mmd` files have no dependencies. No file requires software to be installed
to be read; rendering `.mmd` to images requires the Mermaid CLI (optional).

| Package path | Purpose | Lines | Repository destination | Effect in repository |
|---|---|---|---|---|
| `docs/project-brief.md` | Executive summary, scope, roadmap, acceptance criteria, risks | 290 | `docs/project-brief.md` | Replaces empty file |
| `docs/architecture/infrastructure-diagram.md` | Complete infrastructure overview and component explanation | 137 | `docs/architecture/infrastructure-diagram.md` | New file |
| `docs/architecture/network-topology.md` | VPC, subnets, routing, SGs, traffic paths | 155 | `docs/architecture/network-topology.md` | Replaces empty file |
| `docs/architecture/aws-architecture.md` | AWS account, region, services, cost, availability, lifecycle | 236 | `docs/architecture/aws-architecture.md` | Replaces empty file |
| `docs/networking/ip-addressing.md` | IPv4/CIDR, subnet calculations, allocation plan | 199 | `docs/networking/ip-addressing.md` | New file |
| `docs/networking/dns.md` | Windows DNS, AD-integrated zones, VPC resolver, troubleshooting | 195 | `docs/networking/dns.md` | New file |
| `docs/networking/dhcp.md` | AWS VPC DHCP vs Windows DHCP role; DHCP option sets | 211 | `docs/networking/dhcp.md` | New file |
| `docs/networking/security-groups.md` | Proposed SG rules matrix; deployed rules (none) | 195 | `docs/networking/security-groups.md` | New file |
| `docs/networking/domain-structure.md` | AD forest/domain, OU hierarchy, DC architecture | 217 | `docs/networking/domain-structure.md` | Replaces empty file |
| `docs/networking/users-groups.md` | Account lifecycle, naming, AGDLP, fictional users and groups | 204 | `docs/networking/users-groups.md` | New file |
| `docs/networking/gpo-policies.md` | GPO processing, password/lockout, auditing, policy matrix | 203 | `docs/networking/gpo-policies.md` | Replaces empty file |
| `docs/security/security-baseline.md` | Security objectives, controls and checklist | 174 | `docs/security/security-baseline.md` | New file |
| `docs/security/access-control.md` | Authentication, authorisation, RBAC across AWS/AD/Linux | 159 | `docs/security/access-control.md` | New file |
| `docs/security/iam-policies.md` | IAM roles, instance profile, illustrative policies | 265 | `docs/security/iam-policies.md` | New file |
| `docs/cloud/aws-design.md` | Design rationale, deployment sequence, limitations, expansion | 200 | `docs/cloud/aws-design.md` | New file |
| `docs/cloud/cost-management.md` | Cost drivers, avoidance decisions, Budgets, cleanup | 184 | `docs/cloud/cost-management.md` | New file |
| `docs/cloud/systems-manager.md` | Session Manager, Fleet Manager, ssm-user on DCs, troubleshooting | 225 | `docs/cloud/systems-manager.md` | New file |
| `docs/cloud/terraform-state.md` | S3 backend, encryption, versioning, native locking, bootstrap | 248 | `docs/cloud/terraform-state.md` | New file |
| `infrastructure/diagrams/aws-infrastructure-architecture.mmd` | Source of the overview diagram (infrastructure-diagram.md) | 53 | `infrastructure/diagrams/aws-infrastructure-architecture.mmd` | New file |
| `infrastructure/diagrams/network-topology.mmd` | Source of the network diagram (network-topology.md) | 26 | `infrastructure/diagrams/network-topology.mmd` | New file |
| `infrastructure/diagrams/active-directory-ou-structure.mmd` | Source of the OU diagram (domain-structure.md) | 34 | `infrastructure/diagrams/active-directory-ou-structure.mmd` | New file |
| `infrastructure/diagrams/systems-manager-access-flow.mmd` | Source of the SSM sequence diagram (systems-manager.md) | 23 | `infrastructure/diagrams/systems-manager-access-flow.mmd` | New file |
| `infrastructure/diagrams/terraform-deployment-flow.mmd` | Source of the Terraform flow (terraform-state.md) | 13 | `infrastructure/diagrams/terraform-deployment-flow.mmd` | New file |
| `README.md` | Package overview | 70 | `— (package only)` | — |
| `CHANGELOG.md` | Version history | 41 | `— (package only)` | — |
| `FILE-INDEX.md` | This inventory | 0 | `— (package only)` | — |
| `IMPLEMENTATION-GUIDE.md` | Reading order, integration, diagram rendering | 83 | `— (package only)` | — |
| `DOCUMENTATION-VALIDATION.md` | QA checklist and outcomes | 75 | `— (package only)` | — |
| `REPOSITORY-INTEGRATION/file-mapping.md` | Package → repository mapping and conflicts | 81 | `— (package only)` | — |
| `REPOSITORY-INTEGRATION/copy-procedures.md` | Safe copy commands (macOS/Windows) | 140 | `— (package only)` | — |
| `REPOSITORY-INTEGRATION/integration-checklist.md` | Owner's integration tick-list | 53 | `— (package only)` | — |

**Totals:** 18 documentation files + 5 diagram sources go to the repository (5 replace empty files,
18 are new). 8 files are package-only.
