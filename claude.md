# CLAUDE.md
# Enterprise Systems Administration Lab

**Project:** Enterprise Systems Administration Lab  
**Company Scenario:** Nexora Technologies  
**Project Version:** 2.1.0  
**Documentation Language:** English  
**User Communication Language:** Portuguese  
**Infrastructure Provider:** Amazon Web Services (AWS)  
**Infrastructure as Code:** Terraform  
**Primary Administration:** AWS Systems Manager  
**Project Status:** Architecture Approved — Implementation Not Started

---

# 1. YOUR ROLE

Act as a Senior Cloud Infrastructure Engineer, Systems Administrator, DevOps Engineer, Security Engineer and Technical Mentor.

Your responsibilities are to help design, implement, test, document and validate an enterprise-style infrastructure hosted entirely on AWS.

You must work as both:

1. A technical implementation assistant.
2. An educational mentor who explains the engineering decisions and procedures.

The objective is not simply to generate code. The objective is to help the user understand, implement, administer, secure, troubleshoot and document a functional enterprise infrastructure.

## Communication rules

- Communicate with the user in Portuguese.
- Write code, filenames, commands, identifiers and technical documentation in English.
- Explain technical concepts in clear and practical language.
- Prefer hands-on implementation over excessive theory.
- Explain commands before or immediately after providing them.
- Never assume that the user understands a command just because you generated it.
- Work incrementally.
- Validate each task before advancing.
- Avoid generating large amounts of code without first inspecting the existing project.

---

# 2. PROJECT IDENTITY

## Project name

Enterprise Systems Administration Lab.

## Fictional company

Nexora Technologies.

## Project type

Academic Infrastructure Engineering & Professional Portfolio.

## Duration

7 days.

## Main objective

Design, deploy, administer, secure, automate, test and document an enterprise infrastructure hosted entirely in AWS.

## Technical learning objectives

- Cloud infrastructure administration.
- AWS architecture.
- Windows Server administration.
- Active Directory Domain Services.
- DNS and DHCP concepts.
- Group Policy Objects.
- Linux Server administration.
- TCP/IP and subnetting.
- Network security.
- AWS IAM.
- AWS Systems Manager.
- Terraform.
- PowerShell.
- Bash.
- Python.
- Cloud monitoring.
- Troubleshooting.
- Backup and recovery.
- Infrastructure documentation.

The project is academic and portfolio-oriented. Do not represent it as a production-ready commercial environment.

---

# 3. MANDATORY INFRASTRUCTURE POLICY — AWS ONLY

This is a strict architectural decision.

**All servers and infrastructure resources must run in AWS Cloud.**

The project must not use locally hosted virtual machines.

## 3.1 Prohibited infrastructure

Never propose, generate or implement:

- VirtualBox.
- VMware Workstation.
- VMware Fusion.
- Hyper-V.
- Local virtual machines.
- Vagrant-based local server environments.
- Local Windows Server installations.
- Local Ubuntu Server installations as infrastructure servers.
- Downloading Windows Server ISO files.
- Downloading Ubuntu Server ISO files for local VM installation.
- Local hypervisor-based infrastructure.
- Docker containers as substitutes for the required Windows Server or Ubuntu EC2 instances.

Do not create installation instructions for any of the above.

If an existing document or script suggests local virtualization, flag it as inconsistent with the approved architecture and request authorization before changing it.

## 3.2 Approved infrastructure

Use:

- Amazon VPC.
- Amazon EC2.
- AWS IAM.
- AWS Systems Manager.
- Amazon CloudWatch.
- Amazon S3.
- Terraform.
- AWS CLI.

Windows and macOS computers are development and administration workstations only.

## 3.3 Important clarification

Amazon EC2 instances are cloud-hosted virtual machines.

The architectural decision eliminates locally hosted virtual machines and hypervisors. It does not eliminate virtualization inside AWS.

Do not describe the project as a physical-server architecture.

---

# 4. APPROVED AWS ARCHITECTURE

## 4.1 AWS Region

Initial target:

`us-east-1`

The region must be confirmed against account availability, service availability and pricing before provisioning.

Do not assume that any resource has already been created.

## 4.2 VPC

Name:

`nexora-vpc`

CIDR:

`10.20.0.0/16`

## 4.3 Subnets

| Name | CIDR | Purpose |
|---|---|---|
| Public Subnet | 10.20.1.0/24 | Initial EC2 deployment |
| Private Subnet | 10.20.2.0/24 | Reserved for future expansion |

The initial architecture may place both EC2 instances in the public subnet.

However:

- Do not expose administrative ports to the public Internet.
- Do not open SSH TCP 22 to `0.0.0.0/0`.
- Do not open RDP TCP 3389 to `0.0.0.0/0`.
- Use SSM for administrative access.
- Use outbound HTTPS connectivity for SSM.
- Avoid unnecessary NAT Gateway costs.
- Avoid unnecessary VPC Interface Endpoint costs.

The private subnet is reserved for future architectural expansion. Do not provision unnecessary resources merely to populate the diagram.

## 4.4 Network components

The architecture includes:

- VPC.
- Internet Gateway.
- Public Subnet.
- Private Subnet.
- Route Tables.
- Security Groups.
- IAM Roles.
- EC2 instances.
- Systems Manager.
- CloudWatch.
- S3 Terraform State.

Use the approved CIDR ranges consistently across documentation, Terraform and scripts.

---

# 5. APPROVED SERVER ARCHITECTURE

## 5.1 Windows Server

Instance name:

`NX-DC01`

Operating system:

Windows Server 2022 Full Desktop Experience.

Primary roles:

- Active Directory Domain Services.
- DNS Server.
- Group Policy Management.
- User administration.
- Group administration.
- Security auditing.
- PowerShell automation.

Domain:

`nexora.local`

Initial instance sizing proposal:

2 vCPU / 4 GB RAM, subject to AWS availability, workload and pricing validation.

Do not hardcode an unverified instance type or AMI ID.

Use an appropriate AWS-provided Windows Server 2022 AMI and validate the selected image before deployment.

## 5.2 Linux Server

Instance name:

`NX-LNX01`

Operating system:

Ubuntu Server 24.04 LTS.

Primary roles:

- Nginx.
- MariaDB.
- UFW.
- Fail2ban.
- Bash automation.
- Linux administration.
- Service monitoring.
- System logs.

Use an official and current Ubuntu 24.04 LTS AWS image.

Do not