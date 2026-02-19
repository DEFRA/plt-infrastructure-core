# Subnet layout templates

Pre-approved patterns: each layout defines the full subnet list and **delegations are hard-coded**. Config supplies only CIDRs via **subnetLayout** and **subnetNAddressPrefix**.

**Tokenisation:** Layout files are in **filePathsForTransform**, so the framework’s Replace Tokens task (same as for parameter files) runs on `**/resources/network/vnet/subnet-layouts/*.json` and replaces `#{{ variableName }}` with pipeline variables. No manual replace in code – the pipeline just reads the already-transformed layout and sets the `subnets` variable.

**Tokens (CIDRs only):**
- `#{{ subnet1AddressPrefix }}` … `#{{ subnet6AddressPrefix }}` – from config (subnet1 falls back to subnetAddressPrefix if empty).

**Templates:**
- **1.json** – 6 subnets; subnet1 ACI delegation, rest none.
- **2.json** – 3 subnets; subnet1 ACI delegation, rest none.

To add a template: copy an existing JSON, add/remove subnet objects (delegations fixed in file), use `#{{ subnetNAddressPrefix }}` for CIDRs. Add the file and set subnetLayout in config.
