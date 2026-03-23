#!/usr/bin/env bash
# Normalizes applicationID to upper/lower variants for downstream token replacement.
set -euo pipefail

app_id="${1:-}"
application_id_upper="$(echo "$app_id" | tr '[:lower:]' '[:upper:]')"
application_id_lower="$(echo "$app_id" | tr '[:upper:]' '[:lower:]')"

echo "##vso[task.setvariable variable=applicationID]$application_id_upper"
echo "##vso[task.setvariable variable=applicationIDLower]$application_id_lower"
echo "Normalized applicationID to $application_id_upper, applicationIDLower to $application_id_lower"
