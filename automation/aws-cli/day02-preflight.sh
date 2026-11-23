#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# day02-preflight.sh - WORKSTATION (macOS / Linux / Git Bash) read-only checks
# before provisioning NX-DC01. Creates NOTHING and changes NOTHING in AWS.
#
# Usage: ./day02-preflight.sh [region] [instance-type]
# Example: ./day02-preflight.sh us-east-1 t3.medium
# -----------------------------------------------------------------------------
set -Eeuo pipefail

REGION="${1:-us-east-1}"
INSTANCE_TYPE="${2:-t3.medium}"
AMI_PARAM="/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
DC_IP="10.20.1.10"

log() { printf '\n=== %s ===\n' "$1"; }

command -v aws >/dev/null || { echo "AWS CLI v2 not found" >&2; exit 1; }
command -v session-manager-plugin >/dev/null || echo "WARN: session-manager-plugin not in PATH"

log "Caller identity (must NOT be root)"
aws sts get-caller-identity --output table
ARN="$(aws sts get-caller-identity --query Arn --output text)"
if [[ "$ARN" == *":root" ]]; then
    echo "ERROR: root credentials in use" >&2; exit 1
fi

log "WIN-001 Windows Server 2022 AMI from public SSM parameter"
AMI_ID="$(aws ssm get-parameter --region "$REGION" --name "$AMI_PARAM" \
    --query 'Parameter.Value' --output text)"
echo "AMI: $AMI_ID"
aws ec2 describe-images --region "$REGION" --image-ids "$AMI_ID" \
    --query 'Images[0].{Name:Name,Owner:ImageOwnerAlias,Created:CreationDate,Platform:PlatformDetails,Arch:Architecture,RootGiB:BlockDeviceMappings[0].Ebs.VolumeSize}' \
    --output table

log "WIN-002 Instance type specs ($INSTANCE_TYPE)"
aws ec2 describe-instance-types --region "$REGION" --instance-types "$INSTANCE_TYPE" \
    --query 'InstanceTypes[0].{Type:InstanceType,vCPU:VCpuInfo.DefaultVCpus,MemMiB:MemoryInfo.SizeInMiB,Burstable:BurstablePerformanceSupported}' \
    --output table

log "WIN-002 Availability Zones offering $INSTANCE_TYPE"
aws ec2 describe-instance-type-offerings --region "$REGION" --location-type availability-zone \
    --filters "Name=instance-type,Values=$INSTANCE_TYPE" \
    --query 'InstanceTypeOfferings[].Location' --output text

log "WIN-004 Public subnet 10.20.1.0/24 (from Day 01)"
aws ec2 describe-subnets --region "$REGION" --filters "Name=cidr-block,Values=10.20.1.0/24" \
    --query 'Subnets[].{Id:SubnetId,AZ:AvailabilityZone,Vpc:VpcId,FreeIPs:AvailableIpAddressCount}' \
    --output table

log "Is $DC_IP already in use?"
aws ec2 describe-network-interfaces --region "$REGION" \
    --filters "Name=addresses.private-ip-address,Values=$DC_IP" \
    --query 'NetworkInterfaces[].{Eni:NetworkInterfaceId,Status:Status}' --output table

log "Current DHCP option set of nexora-vpc"
VPC_ID="$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=tag:Name,Values=nexora-vpc" \
    --query 'Vpcs[0].VpcId' --output text)"
echo "VPC: $VPC_ID"
if [[ "$VPC_ID" != "None" ]]; then
    DOPT="$(aws ec2 describe-vpcs --region "$REGION" --vpc-ids "$VPC_ID" \
        --query 'Vpcs[0].DhcpOptionsId' --output text)"
    aws ec2 describe-dhcp-options --region "$REGION" --dhcp-options-ids "$DOPT" --output table
    aws ec2 describe-vpc-attribute --region "$REGION" --vpc-id "$VPC_ID" --attribute enableDnsSupport
    aws ec2 describe-vpc-attribute --region "$REGION" --vpc-id "$VPC_ID" --attribute enableDnsHostnames
else
    echo "WARN: nexora-vpc not found - Day 01 network is not deployed yet"
fi

log "Budgets configured (Day 01 gate)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
aws budgets describe-budgets --account-id "$ACCOUNT_ID" \
    --query 'Budgets[].{Name:BudgetName,Limit:BudgetLimit.Amount,Unit:BudgetLimit.Unit}' \
    --output table || echo "WARN: could not read budgets"

echo -e "\nPreflight finished. Review the output before running terraform plan."
