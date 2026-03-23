#!/usr/bin/env bash
# Validates that additionalDnsConfig is valid JSON when DI is enabled.
set -euo pipefail

document_intelligence_sku="${1:-}"
additional_dns_config="${2:-}"

sku_lower="$(echo "$document_intelligence_sku" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
if [[ -z "$sku_lower" || "$sku_lower" == "none" ]]; then
  echo "Document Intelligence not configured; skipping additionalDnsConfig validation."
  exit 0
fi

if [[ -z "$additional_dns_config" || "$additional_dns_config" == "[]" ]]; then
  echo "additionalDnsConfig empty/blank; skipping validation."
  exit 0
fi

export RAW="$additional_dns_config"
python3 -c "import os, json; json.loads(os.environ['RAW'])"
