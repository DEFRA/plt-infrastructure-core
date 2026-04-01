# Virtual network deployment

The template number (**subnetLayout** in config) selects which parameter file is used. Each folder is a self-contained VNet "template" – human-readable, no loops in code.

- **1/** – 7 subnets (subnet1 ACI delegation, rest none).
  - Subnets `1`-`7` use `"routeTableNumber": "#{{ subnetNRouteTable }}"` token pattern.
  - If a given `subnetNRouteTable` is not set in `core.yaml`, token replacement results in an empty string and the VNet template defaults it to route table `1`.
- **2/** – 3 subnets; subnets `1`-`3` use the same `"routeTableNumber": "#{{ subnetNRouteTable }}"` token pattern.
  - Unset `subnetNRouteTable` values default to route table `1` in the VNet template.

Config supplies: `subnetLayout` (e.g. `1` or `2`), `addressPrefixes`, `subnet1AddressPrefix` … `subnet6AddressPrefix` (as needed), plus the usual `virtualNetworkName`, `location`, `subType`, etc.

To add a template: add a new folder (e.g. **4/**), copy `virtual-network.parameters.json` from an existing folder, add/remove subnet objects (keep the `routeTable.routeTableNumber` token pattern). Do NOT include a `name` token inside each subnet object: `resources/network/vnet/virtual-network.bicep` now computes subnet names deterministically from `subType/serviceCode/deploymentEnvInstance/regionCode` plus the subnet index.

## `aad-group.json` manifest spec

The pipeline uses `scripts/pipeline/Create-AADGroups.ps1` to create/update Entra ID groups using Microsoft Graph, based on a JSON manifest file located in `plt-config` at:

- `config/<applicationID>/<instance>/aad-group.json`

### Top-level shape

- `userADGroups` (optional): array of group objects
- `accessADGroups` (optional): array of group objects

If a property is missing or an array is empty, that section is skipped.

### Group object shape

- `displayName` (required): string
- `description` (optional): string
- `Owners` (optional): object containing arrays of principals
- `Members` (optional): object containing arrays of principals

`Owners` / `Members` support these arrays (any may be empty):

- `users`: array of UPN/email strings
- `groups`: array of group display names
- `serviceprincipals`: array of service principal display names
