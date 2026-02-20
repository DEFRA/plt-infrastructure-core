# Virtual network deployment

The template number (**subnetLayout** in config) selects which parameter file is used. Each folder is a self-contained VNet "template" – human-readable, no loops in code.

- **1/** – 6 subnets (subnet1 ACI delegation, rest none); each subnet has `"routeTable": { "id": "#{{ subnetNRouteTableResourceId }}" }` (N=1..6). Config `subnetNRouteTable`: 0=none, 1=01 default, 2=02, 3=03.
- **2/** – 3 subnets; same pattern with `subnet1RouteTableResourceId` … `subnet3RouteTableResourceId`.

Config supplies: `subnetLayout` (e.g. `1` or `2`), `addressPrefixes`, `subnet1AddressPrefix` … `subnet6AddressPrefix` (as needed), plus the usual `virtualNetworkName`, `location`, `subType`, etc.

To add a template: add a new folder (e.g. **3/**), copy `virtual-network.parameters.json` from an existing folder, add/remove subnet objects. Use `"routeTable": { "id": "#{{ subnetNRouteTableResourceId }}" }` (N=1..6) so config can set per-subnet route table via `subnetNRouteTable`. Set `subnetLayout` in config to use it.
