# Virtual network deployment

The template number (**subnetLayout** in config) selects which parameter file is used. Each folder is a self-contained VNet "template" – human-readable, no loops in code.

- **1/** – 6 subnets (subnet1 ACI delegation, rest none).
  - Subnets `1`-`5` always use `"routeTableNumber": 1`.
  - Subnets `6` and `7` use `"routeTableNumber": "#{{ subnet6RouteTable }}"` and `"routeTableNumber": "#{{ subnet7RouteTable }}"` from `core.yaml`.
- **2/** – 3 subnets; subnets `1`-`3` always use `"routeTableNumber": 1`.

Config supplies: `subnetLayout` (e.g. `1` or `2`), `addressPrefixes`, `subnet1AddressPrefix` … `subnet6AddressPrefix` (as needed), plus the usual `virtualNetworkName`, `location`, `subType`, etc.

To add a template: add a new folder (e.g. **4/**), copy `virtual-network.parameters.json` from an existing folder, add/remove subnet objects (keep the `routeTable.routeTableNumber` token pattern). Do NOT include a `name` token inside each subnet object: `resources/network/vnet/virtual-network.bicep` now computes subnet names deterministically from `subType/serviceCode/deploymentEnvInstance/regionCode` plus the subnet index.
