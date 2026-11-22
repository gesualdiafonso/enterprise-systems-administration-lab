# Cost Management

| Field | Value |
|---|---|
| **Project** | Enterprise Systems Administration Lab (ESAL) |
| **Document** | Cost Management |
| **Version** | 1.0.0 |
| **Status** | DRAFT / PROPOSED |
| **Last updated** | 2026-11-22 |
| **Scope** | Billing fundamentals, cost components, avoidance decisions, start/stop, Budgets, Cost Explorer, cleanup |

> **No prices are stated in this document.** Actual pricing depends on **region, instance type,
> operating system, usage and date**. Always confirm on the official AWS pricing pages and the
> AWS Pricing Calculator before deploying. No real cost estimate has been produced.

---

## 1. AWS Billing Fundamentals

| Concept | Meaning |
|---|---|
| Pay-as-you-go | Charged for what is provisioned/used, typically per second, hour, GB-month or request |
| On-Demand | No commitment; the pricing model used in this lab |
| Free Tier / credits | Depends on account age and plan — check your own account in Billing |
| Billing granularity | Varies by service; see each pricing page |
| Tags | Cost allocation tags (`Project=ESAL`) must be **activated** in Billing to appear in reports |

## 2. EC2 Compute Cost

| Factor | Effect |
|---|---|
| Instance type and size | Larger = more expensive |
| Operating system | **Windows instances cost more** than Linux for the same type (licence included) |
| State | Charged while **running**; not charged for compute while **stopped** |
| Burstable (T-family) credits | In *unlimited* mode, sustained CPU above baseline can add charges |

## 3. Windows Licensing Considerations

- AWS-provided Windows Server AMIs use **License Included** pricing: the Windows licence cost is
  part of the hourly instance price.
- No separate Windows Server licence purchase is needed for the lab.
- Bring-your-own-licence (BYOL) options exist but require dedicated infrastructure and are out of
  scope.
- Windows Server is typically the **largest single cost item** in this project — keep NX-DC01
  stopped when not in use.

## 4. EBS Storage

| Item | Billing behaviour |
|---|---|
| gp3 volumes | Charged per GB-month **for as long as the volume exists — including while the instance is stopped** |
| Snapshots | Charged per GB-month of stored data |
| Unattached volumes | Still charged — delete after verification |

## 5. Public IPv4 Charges

AWS charges for **public IPv4 addresses while they are assigned**, including auto-assigned
public IPs on running instances and Elastic IPs (whether in use or idle).

| Design choice | Effect |
|---|---|
| Auto-assigned public IP | Released when the instance stops → no charge while stopped |
| No permanent Elastic IPs | Avoids idle-address charges |
| Two instances | Two public IPv4 addresses while running |

## 6. CloudWatch Charges

| Item | Cost driver | Mitigation |
|---|---|---|
| Basic EC2 metrics | Included | — |
| Custom metrics (CloudWatch agent) | Per metric | Collect only memory/disk essentials |
| Logs | Ingestion + storage | Few log groups; **short retention** (7–14 days) |
| Alarms | Per alarm | A handful of alarms only |
| Detailed monitoring | Per instance | Not enabled |

## 7. S3 Charges

The Terraform state bucket stores small objects; costs come from storage, requests and
versions. Expected to be minimal; noncurrent-version expiration keeps it bounded.

## 8. NAT Gateway Cost Avoidance

A NAT Gateway bills **per hour** while it exists **plus per GB processed**, whether or not
instances are running. For a lab that is idle most of the time, this fixed hourly cost would
dominate the bill.

| Option | Recurring fixed cost | Chosen |
|---|---|---|
| NAT Gateway for private subnet | Hourly + data processing | No |
| Public subnet + public IPv4 + no inbound rules | Per public IPv4 while running | **Yes** |

## 9. VPC Endpoint Cost Considerations

| Endpoint type | Billing | Needed for SSM in a private subnet |
|---|---|---|
| Interface endpoints (AWS PrivateLink) | Per endpoint **per AZ per hour** + per GB | `ssm`, `ssmmessages`, `ec2messages` (+ `logs`, `kms`, `s3` as needed) |
| Gateway endpoint (S3, DynamoDB) | No hourly charge | Optional |

Several interface endpoints running 24/7 would exceed the cost of the public-IPv4 approach for
this lab. They are a **future improvement** when the private subnet is used.

## 10. Start/Stop Strategy

| Rule | Detail |
|---|---|
| Start only for work sessions | Start DC first, then Linux server |
| Stop at the end of every session | **Mandatory** |
| Verify | Check instance state after stopping |
| Remember | EBS still billed while stopped; public IPv4 released |

Illustrative commands (**not executed**):

```bash
# Start (DC first)
aws ec2 start-instances --instance-ids <nx-dc01-id> --profile esal
aws ec2 wait instance-running --instance-ids <nx-dc01-id> --profile esal
aws ec2 start-instances --instance-ids <nx-lnx01-id> --profile esal

# Stop both
aws ec2 stop-instances --instance-ids <nx-dc01-id> <nx-lnx01-id> --profile esal

# Verify
aws ec2 describe-instances --filters Name=tag:Project,Values=ESAL \
  --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,State.Name]" --output table
```

## 11. AWS Budgets

| Item | Proposal | Status |
|---|---|---|
| Budget type | Monthly cost budget | PLANNED |
| Amount | Defined by the author before deployment | **Decision required** |
| Alerts | Actual 50 %, 80 %, 100 %; Forecasted 100 % | PLANNED |
| Notification | Author's email | PLANNED |

> **AWS Budgets notifications are alerts, not hard spending limits.** They do not stop resources
> by themselves. Budget *actions* can be configured but are out of scope for this lab.

## 12. Cost Explorer

- Filter by tag `Project=ESAL` (after activating the cost allocation tag).
- Group by **Service** and **Usage type** to see EC2 compute, EBS, public IPv4 and CloudWatch
  separately.
- Review at least at the end of each phase; record observations (not invented figures) in evidence.

## 13. Cleanup Checklist

| # | Item | Command / location | Done |
|---|---|---|---|
| 1 | Collect final evidence | `evidence/` | ☐ |
| 2 | Obtain **written authorisation** to destroy | — | ☐ |
| 3 | `terraform plan -destroy` reviewed | Main configuration | ☐ |
| 4 | `terraform destroy` | Main configuration | ☐ |
| 5 | No instances remain | `aws ec2 describe-instances` (tag filter) | ☐ |
| 6 | No orphan EBS volumes | `aws ec2 describe-volumes --filters Name=status,Values=available` | ☐ |
| 7 | No unneeded snapshots / AMIs | `aws ec2 describe-snapshots --owner-ids self` | ☐ |
| 8 | No Elastic IPs | `aws ec2 describe-addresses` | ☐ |
| 9 | CloudWatch log groups deleted or expired | `aws logs describe-log-groups --log-group-name-prefix /nexora` | ☐ |
| 10 | State bucket: decide keep (archive) or delete (after state no longer needed) | S3 | ☐ |
| 11 | Budget kept until the bill shows zero lab usage | Budgets | ☐ |

## 14. Cost Risks

| Risk | Cause | Mitigation |
|---|---|---|
| Instances left running | Forgot to stop | End-of-session stop routine; budget alerts |
| Unexpected NAT / endpoint charges | Created during experiments | Not in design; review `terraform plan` |
| Large log volumes | Verbose logs, long retention | Short retention; selective collection |
| Orphan volumes/snapshots | Manual tests | Cleanup checklist |
| T-instance unlimited credits | Sustained high CPU | Monitor CPU; consider `standard` credit mode |
| Account plan limitations | Free plan may restrict some instance types/services | Check eligibility before deploying |

## References

- AWS — Amazon EC2 On-Demand pricing: <https://aws.amazon.com/ec2/pricing/on-demand/>
- AWS — Amazon EBS pricing: <https://aws.amazon.com/ebs/pricing/>
- AWS — Amazon VPC pricing (public IPv4, NAT Gateway): <https://aws.amazon.com/vpc/pricing/>
- AWS — AWS PrivateLink pricing: <https://aws.amazon.com/privatelink/pricing/>
- AWS — Amazon CloudWatch pricing: <https://aws.amazon.com/cloudwatch/pricing/>
- AWS — Amazon S3 pricing: <https://aws.amazon.com/s3/pricing/>
- AWS — AWS Pricing Calculator: <https://calculator.aws/>
- AWS — AWS Budgets: <https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html>
- AWS — AWS Cost Explorer: <https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html>
- AWS — AWS Free Tier: <https://aws.amazon.com/free/>
