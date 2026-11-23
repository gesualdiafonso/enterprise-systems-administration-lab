#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# run-dc-script.sh - WORKSTATION. Runs one script from automation/powershell/
# scripts on NX-DC01 through SSM Run Command (AWS-RunPowerShellScript).
#
# The library, the config file and the script are copied to C:\Nexora on the
# instance (gzip + base64 inside the command), then the script is executed as SYSTEM.
# If the script exits 3010, the SSM Agent reboots the instance and runs the
# command again; this wrapper keeps waiting until the final status.
#
# Usage : ./run-dc-script.sh <script.ps1> [extra PowerShell arguments...]
# Example: ./run-dc-script.sh 01-Set-ServerBaseline.ps1
# Env    : AWS_REGION (default us-east-1), DC_NAME (default NX-DC01),
#          TIMEOUT_MIN (default 60), AWS_PROFILE (standard)
#          DRY_RUN=1 prints the SSM parameters and exits without calling AWS
# Requires: aws CLI v2, jq, base64
# -----------------------------------------------------------------------------
set -Eeuo pipefail

REGION="${AWS_REGION:-us-east-1}"
DC_NAME="${DC_NAME:-NX-DC01}"
TIMEOUT_MIN="${TIMEOUT_MIN:-60}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PS_ROOT="$REPO_ROOT/automation/powershell"

[[ $# -ge 1 ]] || { echo "Usage: $0 <script.ps1> [args...]" >&2; exit 2; }
SCRIPT_NAME="$(basename "$1")"; shift
SCRIPT_ARGS="$*"
SCRIPT_PATH="$PS_ROOT/scripts/$SCRIPT_NAME"
[[ -f "$SCRIPT_PATH" ]] || { echo "Script not found: $SCRIPT_PATH" >&2; exit 2; }
for t in aws jq base64; do command -v "$t" >/dev/null || { echo "$t not found" >&2; exit 1; }; done

# gzip + base64 keeps the command small (SSM limits the size of command parameters).
b64() { gzip -9 -n -c < "$1" | base64 | tr -d '\n'; }

# PowerShell payload: stage files under C:\Nexora, run the script, propagate exit code.
PAYLOAD="$(cat <<EOF
\$ErrorActionPreference = 'Stop'
\$root = 'C:\\Nexora'
\$files = [ordered]@{
  'lib\\NexoraLab.psm1'      = '$(b64 "$PS_ROOT/lib/NexoraLab.psm1")'
  'config\\nexora-ad.psd1'   = '$(b64 "$PS_ROOT/config/nexora-ad.psd1")'
  'scripts\\$SCRIPT_NAME'    = '$(b64 "$SCRIPT_PATH")'
}
foreach (\$k in \$files.Keys) {
  \$p = Join-Path \$root \$k
  New-Item -ItemType Directory -Force -Path (Split-Path \$p) | Out-Null
  \$in = New-Object IO.MemoryStream(,[Convert]::FromBase64String(\$files[\$k]))
  \$gz = New-Object IO.Compression.GZipStream(\$in, [IO.Compression.CompressionMode]::Decompress)
  \$out = New-Object IO.MemoryStream
  \$gz.CopyTo(\$out); \$gz.Dispose()
  [IO.File]::WriteAllBytes(\$p, \$out.ToArray())
}
& (Join-Path \$root 'scripts\\$SCRIPT_NAME') $SCRIPT_ARGS
exit \$LASTEXITCODE
EOF
)"

SIZE=${#PAYLOAD}
if (( SIZE > 60000 )); then
    echo "WARN: payload is ${SIZE} bytes; SSM may reject very large commands" >&2
fi

PARAMS="$(jq -n --arg cmd "$PAYLOAD" --arg t "$(( TIMEOUT_MIN * 60 ))" \
    '{commands: [$cmd], executionTimeout: [$t]}')"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN: SSM parameters for $SCRIPT_NAME (${SIZE} bytes), nothing sent to AWS:"
    echo "$PARAMS"
    exit 0
fi

ARN="$(aws sts get-caller-identity --query Arn --output text)"
[[ "$ARN" != *":root" ]] || { echo "ERROR: refusing to run with root credentials" >&2; exit 1; }

INSTANCE_ID="$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=$DC_NAME" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' --output text)"
[[ -n "$INSTANCE_ID" && "$INSTANCE_ID" != "None" && "$INSTANCE_ID" != *$'\t'* ]] \
    || { echo "ERROR: expected exactly one running instance named $DC_NAME, got: '$INSTANCE_ID'" >&2; exit 1; }

PING="$(aws ssm describe-instance-information --region "$REGION" \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query 'InstanceInformationList[0].PingStatus' --output text)"
[[ "$PING" == "Online" ]] || { echo "ERROR: SSM Agent on $INSTANCE_ID is '$PING' (expected Online)" >&2; exit 1; }

echo "==> $SCRIPT_NAME on $DC_NAME ($INSTANCE_ID, $REGION) - payload ${SIZE} bytes"
COMMAND_ID="$(aws ssm send-command --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --document-name AWS-RunPowerShellScript \
    --comment "ESAL $SCRIPT_NAME" \
    --parameters "$PARAMS" \
    --query 'Command.CommandId' --output text)"
echo "    CommandId: $COMMAND_ID"

STATUS="Pending"
DEADLINE=$(( $(date +%s) + TIMEOUT_MIN * 60 + 300 ))
while :; do
    sleep 10
    STATUS="$(aws ssm get-command-invocation --region "$REGION" \
        --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
        --query 'Status' --output text 2>/dev/null || echo Pending)"
    case "$STATUS" in
        Pending|InProgress|Delayed) printf '    %s ... %s\n' "$(date +%H:%M:%S)" "$STATUS" ;;
        *) break ;;
    esac
    (( $(date +%s) < DEADLINE )) || { echo "ERROR: timed out waiting for $COMMAND_ID" >&2; exit 1; }
done

echo "==> Status: $STATUS"
aws ssm get-command-invocation --region "$REGION" --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
    --query 'StandardOutputContent' --output text
ERR="$(aws ssm get-command-invocation --region "$REGION" --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
    --query 'StandardErrorContent' --output text)"
if [[ -n "$ERR" && "$ERR" != "None" ]]; then
    echo "---- stderr ----"; echo "$ERR"
fi
echo "(Output is truncated by SSM at 24,000 characters; full logs: C:\\Nexora\\logs on the instance.)"

[[ "$STATUS" == "Success" ]]
