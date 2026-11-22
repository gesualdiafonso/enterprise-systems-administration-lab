# IAM Policies

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | IAM Policies |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | IAM users and roles, policies, instance profiles, workstation authentication, trust relationships, examples |

> **Status:** No IAM resource has been created. **All JSON policies in this document are
> ILLUSTRATIVE EXAMPLES — VALIDATION REQUIRED** (IAM Access Analyzer policy validation and a
> functional test) before any use. Account IDs are placeholders (`111122223333`).

---

## 1. IAM Users and Roles

| Principal type | Credentials | Use in this project |
|---|---|---|
| Root user | Email + password + MFA | Account-level tasks only; no access keys |
| IAM user | Password and/or **long-term** access keys | **Avoided**; fallback only if IAM Identity Center is unavailable |
| IAM role | **Temporary** credentials via STS | EC2 instance role; permission sets (Identity Center creates roles) |
| IAM Identity Center user | SSO sign-in → temporary role credentials | Daily administration from the workstations |

## 2. IAM Policies

| Policy type | Attached to | Project use |
|---|---|---|
| AWS managed | Roles/users/groups | `AmazonSSMManagedInstanceCore`, `CloudWatchAgentServerPolicy` |
| Customer managed | Roles/users/groups | Tag-scoped session permissions (example §10.3) |
| Inline | One principal | Avoid (harder to audit) |
| Trust policy | Role | Defines who can assume the role (§8) |
| Resource-based | Resource (e.g. S3 bucket policy) | State bucket TLS-only policy |
| Permissions boundary / SCP | — | Out of scope (single-account lab) |

Evaluation rule: an explicit **Deny** always wins; otherwise access requires an explicit **Allow**.

## 3. EC2 Instance Profiles

An **instance profile** is the container that passes an IAM role to an EC2 instance. Software on
the instance (SSM Agent, CloudWatch agent, AWS CLI) obtains temporary, auto-rotated credentials
from the Instance Metadata Service.

| Resource | Proposed name | Status |
|---|---|---|
| IAM role | `nexora-ec2-ssm-role` | PROPOSED |
| Instance profile | `nexora-ec2-ssm-profile` | PROPOSED |
| Attached to | NX-DC01, NX-LNX01 | PROPOSED |

## 4. AmazonSSMManagedInstanceCore

AWS managed policy that grants the permissions the SSM Agent needs for core Systems Manager
functionality: registering the managed node, receiving commands, opening Session Manager
channels (`ssm`, `ssmmessages`, `ec2messages` API actions).

| Aspect | Note |
|---|---|
| Sufficient for | Session Manager, Run Command, Inventory basics |
| Not included | CloudWatch agent publishing → add `CloudWatchAgentServerPolicy` |
| Not included | Writing session logs to S3/CloudWatch → add scoped permissions if enabled |
| Caution | Do **not** use the deprecated `AmazonEC2RoleforSSM` (much broader) |

## 5. Developer Workstation Authentication

| Option | Credential lifetime | Recommendation |
|---|---|---|
| IAM Identity Center + `aws configure sso` | Temporary (session-based) | **Recommended** |
| IAM user + access keys in `~/.aws/credentials` | Long-term until rotated | Fallback only; MFA, rotation, never in Git |
| Root access keys | Long-term, unlimited | **Never** |

Workstation setup (illustrative — **not executed**):

```bash
aws configure sso --profile esal
#   SSO session name: esal
#   SSO start URL:    https://<your-identity-center-portal>.awsapps.com/start
#   SSO region:       us-east-1
#   Account / role:   <lab account> / <permission set>
#   Default region:   us-east-1

aws sso login --profile esal
aws sts get-caller-identity --profile esal
```

## 6. Temporary Credentials

| Property | Benefit |
|---|---|
| Expire automatically | Leaked credentials have limited value |
| No storage in code | Nothing to commit by mistake |
| Issued per session | Clear audit trail in CloudTrail |
| Obtained via STS | Same mechanism for humans (SSO) and workloads (instance profiles) |

## 7. IAM Identity Center Recommendation

1. Enable IAM Identity Center in the account (organisation instance or account instance —
   VALIDATION REQUIRED for the account type).
2. Create one user for the author; enforce MFA.
3. Create a permission set for lab administration (start from a broad AWS managed policy only if
   necessary, then narrow — see §10.4).
4. Optionally create a read-only permission set for day-to-day browsing.
5. Assign the user to the account with the permission set(s).

## 8. Trust Relationships

The instance role must trust the EC2 service.

**Example 8.1 — Trust policy for `nexora-ec2-ssm-role` (ILLUSTRATIVE — VALIDATION REQUIRED)**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowEC2ToAssumeRole",
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Explanation: only the EC2 service can assume this role, and only on behalf of instances launched
with the corresponding instance profile. Launching an instance with a profile additionally
requires `iam:PassRole` for the person running Terraform.

## 9. Security Risks

| Risk | Example | Mitigation |
|---|---|---|
| Over-privileged role | `AdministratorAccess` on the instance role | Only SSM + CloudWatch agent policies |
| Wildcard `iam:PassRole` | Lets a user pass any role, including admin roles | Restrict `Resource` to the specific role ARN |
| Long-lived keys | Access keys in `~/.aws/credentials` or Git | Identity Center; secret scanning |
| Unrestricted Session Manager | Any principal can open shells on any instance | Tag-based conditions (§10.3) |
| IMDSv1 credential theft | SSRF extracts role credentials | IMDSv2 required |
| Policy drift | Manual console edits | Manage roles in Terraform |

## 10. Policy Design Examples

> **All examples: ILLUSTRATIVE — VALIDATION REQUIRED.** They are not production configuration.
> Validate each with IAM Access Analyzer and test functionally before use.

### 10.1 Instance role permissions (managed policies)

```hcl
# Illustrative Terraform — attach AWS managed policies to the instance role
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
```

### 10.2 Scoped `iam:PassRole` for the Terraform operator

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PassOnlyTheLabInstanceRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::111122223333:role/nexora-ec2-ssm-role",
      "Condition": {
        "StringEquals": { "iam:PassedToService": "ec2.amazonaws.com" }
      }
    }
  ]
}
```

### 10.3 Session Manager limited to ESAL-tagged instances

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StartSessionOnlyOnEsalInstances",
      "Effect": "Allow",
      "Action": "ssm:StartSession",
      "Resource": "arn:aws:ec2:us-east-1:111122223333:instance/*",
      "Condition": {
        "StringEquals": { "ssm:resourceTag/Project": "ESAL" }
      }
    },
    {
      "Sid": "AllowApprovedSessionDocuments",
      "Effect": "Allow",
      "Action": "ssm:StartSession",
      "Resource": [
        "arn:aws:ssm:us-east-1:111122223333:document/SSM-SessionManagerRunShell",
        "arn:aws:ssm:us-east-1::document/AWS-StartPortForwardingSession"
      ]
    },
    {
      "Sid": "ManageOwnSessionsOnly",
      "Effect": "Allow",
      "Action": ["ssm:TerminateSession", "ssm:ResumeSession"],
      "Resource": "arn:aws:ssm:*:*:session/${aws:userid}-*"
    },
    {
      "Sid": "ReadOnlyDiscovery",
      "Effect": "Allow",
      "Action": [
        "ssm:DescribeSessions",
        "ssm:GetConnectionStatus",
        "ssm:DescribeInstanceInformation",
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

Notes: the session-resource ARN pattern differs for IAM Identity Center users (the session ID is
derived from the role session); **validate the pattern** against the AWS documentation and
CloudTrail events before relying on it.

### 10.4 Narrowing the administrator permission set

| Step | Action |
|---|---|
| 1 | Start the first deployment with a broad permission set **only if necessary** |
| 2 | Enable CloudTrail event review / IAM Access Analyzer policy generation |
| 3 | Generate a policy from actual activity |
| 4 | Replace the broad set with the generated, reviewed policy |

Avoid recommending `"Action": "*", "Resource": "*"` policies as a final configuration.

## 11. Validation (post-deployment)

```bash
aws iam get-role --role-name nexora-ec2-ssm-role --query "Role.AssumeRolePolicyDocument"
aws iam list-attached-role-policies --role-name nexora-ec2-ssm-role
aws iam get-instance-profile --instance-profile-name nexora-ec2-ssm-profile
aws accessanalyzer validate-policy --policy-type IDENTITY_POLICY \
  --policy-document file://policy.json
```

| Check | Expected | Status |
|---|---|---|
| Role trust principal | `ec2.amazonaws.com` only | NOT TESTED |
| Attached policies | Exactly the two managed policies | NOT TESTED |
| Access Analyzer findings | No errors/security warnings | NOT TESTED |

## References

- AWS — IAM roles: <https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html>
- AWS — Security best practices in IAM: <https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html>
- AWS — Use an IAM role to grant permissions to applications on EC2: <https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html>
- AWS — AmazonSSMManagedInstanceCore: <https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonSSMManagedInstanceCore.html>
- AWS — CloudWatchAgentServerPolicy: <https://docs.aws.amazon.com/aws-managed-policy/latest/reference/CloudWatchAgentServerPolicy.html>
- AWS — Configure IAM Identity Center authentication with the AWS CLI: <https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html>
- AWS — Session Manager: additional sample IAM policies: <https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html>
- AWS — IAM Access Analyzer policy validation: <https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-validation.html>
