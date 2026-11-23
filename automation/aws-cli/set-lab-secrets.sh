#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# set-lab-secrets.sh - WORKSTATION. Stores the lab passwords in SSM Parameter
# Store as SecureString (encrypted with the AWS managed key aws/ssm).
#
# Passwords are typed with hidden input: they never appear on screen, in shell
# history, in Git, or in Terraform state. Existing parameters are skipped
# unless --overwrite is given.
#
# Usage: ./set-lab-secrets.sh [--overwrite]
# Env  : AWS_REGION (default us-east-1), AWS_PROFILE (standard)
#
# Password rules (Windows complexity + project policy): at least 14 characters
# with upper case, lower case, digits and symbols.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

REGION="${AWS_REGION:-us-east-1}"
OVERWRITE="false"
[[ "${1:-}" == "--overwrite" ]] && OVERWRITE="true"

declare -a NAMES=(
    "/nexora/windows/administrator-password|Built-in Administrator (break-glass, becomes NEXORA\\Administrator)"
    "/nexora/ad/dsrm-password|Directory Services Restore Mode (DSRM)"
    "/nexora/ad/initial-user-password|Initial password of the 15 standard users (changed at first logon)"
    "/nexora/ad/admin-account-password|Password of the adm- accounts (Fleet Manager logon)"
)

ARN="$(aws sts get-caller-identity --query Arn --output text)"
[[ "$ARN" != *":root" ]] || { echo "ERROR: refusing to run with root credentials" >&2; exit 1; }
echo "Identity: ${ARN##*/}  Region: $REGION"

valid() {
    local p="$1"
    [[ ${#p} -ge 14 && "$p" =~ [A-Z] && "$p" =~ [a-z] && "$p" =~ [0-9] && "$p" =~ [^A-Za-z0-9] ]]
}

for entry in "${NAMES[@]}"; do
    name="${entry%%|*}"; label="${entry#*|}"
    if aws ssm get-parameter --region "$REGION" --name "$name" >/dev/null 2>&1 && [[ "$OVERWRITE" != "true" ]]; then
        echo "SKIP  $name (exists; use --overwrite to replace)"
        continue
    fi
    echo
    echo "$label"
    while :; do
        read -r -s -p "  Password for $name: " p1; echo
        read -r -s -p "  Confirm: " p2; echo
        if [[ "$p1" != "$p2" ]]; then echo "  Passwords do not match."; continue; fi
        if ! valid "$p1"; then echo "  Needs >= 14 chars with upper, lower, digit and symbol."; continue; fi
        break
    done
    # The value goes through a pipe (printf is a shell builtin), never as a
    # command-line argument, so it does not show up in `ps` output.
    # AWS does not allow --tags together with --overwrite.
    if aws ssm get-parameter --region "$REGION" --name "$name" >/dev/null 2>&1; then
        printf '%s' "$p1" | jq -Rs --arg n "$name" \
            '{Name: $n, Type: "SecureString", Value: ., Overwrite: true}' \
            | aws ssm put-parameter --region "$REGION" --cli-input-json file:///dev/stdin >/dev/null
    else
        printf '%s' "$p1" | jq -Rs --arg n "$name" \
            '{Name: $n, Type: "SecureString", Value: ., Tags: [{Key: "Project", Value: "ESAL"}]}' \
            | aws ssm put-parameter --region "$REGION" --cli-input-json file:///dev/stdin >/dev/null
    fi
    unset p1 p2
    echo "OK    $name"
done

echo
aws ssm describe-parameters --region "$REGION" \
    --parameter-filters "Key=Name,Option=BeginsWith,Values=/nexora/" \
    --query 'Parameters[].{Name:Name,Type:Type,Version:Version,Modified:LastModifiedDate}' --output table
