#!/usr/bin/env bash
# Validates that additionalDnsConfig is valid JSON when DI is enabled.
# Empty, whitespace-only, [], JSON null, or omitted variable are all acceptable (zero or more DNS entries).
set -euo pipefail

document_intelligence_sku="${1:-}"
# Trim; ADO may pass whitespace or an undefined macro as empty.
additional_dns_config="$(printf '%s' "${2:-}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

sku_lower="$(echo "$document_intelligence_sku" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
if [[ -z "$sku_lower" || "$sku_lower" == "none" ]]; then
  echo "Document Intelligence not configured; skipping additionalDnsConfig validation."
  exit 0
fi

if [[ -z "$additional_dns_config" || "$additional_dns_config" == "[]" || "$additional_dns_config" == "null" ]]; then
  echo "additionalDnsConfig empty or absent; skipping validation."
  exit 0
fi

export RAW="$additional_dns_config"
python3 -c "
import json, os, sys
raw = os.environ.get('RAW', '').strip()
if not raw or raw in ('[]', 'null'):
    sys.exit(0)
data = json.loads(raw)
if data is None or data == []:
    sys.exit(0)
"
