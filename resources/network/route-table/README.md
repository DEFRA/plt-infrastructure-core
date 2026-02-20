# Route table deployment

Same pattern as VNet templates: **numbered template folders** and **config selects which route table each subnet uses**.

- **1/** – default route table (01). **Always deployed.** Routes in `route-table/1/route-table.parameters.json`.
- **2/**, **3/**, … – alternate route tables. Deployed **only when referenced** (e.g. `subnet3RouteTable: 3`). Add folders as needed.

**Config (per subnet):**

- `subnet1RouteTable` … `subnet6RouteTable`: `0` = no route table, `1` = 01 (default), `2` = 02, `3` = 03. Omit = 1.
- `routeTableName` (from naming), `firewallVirtualApplianceIp` (for default route in templates that use it).

The pipeline deploys only 01 (always) and any 02, 03, … that are referenced in config. Per-subnet route table resource IDs are set from config so the framework’s token replacement fills them in the VNet parameter file.

To add a template: add a folder (e.g. **4/**), copy `route-table.parameters.json` from an existing folder, set `routeTableSuffix` and edit the `routes` array, then use `subnetNRouteTable: 4` in config.
