# Changelog

All notable changes to this repository should be documented in this file.

## [1.6.0] - 2026-10-02

### Added

- **Private Key Vault (`KVT`)** — Optional. Set `keyVault: true` in instance `core.yaml` to deploy a private Key Vault into the APP resource group (requires `APP` in `platformResourceGroups`). SharedDefra `key-vault.vault` **0.5.3**, RBAC auth, soft-delete, public access disabled, vault private endpoint on the PEP subnet, DNS A record for `{name}.vaultcore.azure.net`. Grants Key Vault Secrets Officer to `appRgContributor` when resolvable. Parallel **Deploy Azure Services** job `azure_key_vault` (depends on `landing_zone` only). Naming via `get-names` / `Set-ResourceNames` (`keyVaultName`).

### Changed

- **PostgreSQL Flexible Server auth** — `passwordAuth` flipped to **Enabled** (Entra auth remains enabled). Apps can use stable password-based `DATABASE_URL` secrets while admins/automation keep Entra MI.

## [1.5.0] - 2026-09-30

### Added

- **Private PostgreSQL Flexible Server** — Optional. Set `postgresFlexibleServer` to a subnet key (e.g. `subnet5`) in instance `core.yaml` to deploy a VNet-injected Flexible Server into the APP resource group (requires `APP` in `platformResourceGroups`). The value selects which VNet subnet hosts the server (must be delegated to `Microsoft.DBforPostgreSQL/flexibleServers`; layout 1 defaults to subnet 5). Defaults to Burstable **Standard_B1ms**, 32 GB, PostgreSQL **16** via public AVM `db-for-postgre-sql/flexible-server` **0.16.1** (SharedDefra still caps at 15), high availability disabled. **No public connectivity** (delegated subnet injection + server-scoped private DNS zone `{server}.privatelink.postgres.database.azure.com` in the APP RG — avoids the centrally managed `privatelink.postgres.database.azure.com` zone — spoke-linked and hub-linked). **Entra authentication only** (`passwordAuth` disabled): creates a platform user-assigned MI as Entra admin for later app-deploy DB automation; when a Container Apps Environment exists in the same APP RG, its system-assigned MI is also granted Entra admin. Per-app database users remain an app-deploy concern. Set to `none` or omit to skip.
- **Naming resource type `PSQ`** — PostgreSQL Flexible Server naming via `get-names` / `Set-ResourceNames` (`postgresFlexibleServerName`).

### Changed

- **Layout 1 subnet 5** — Delegation moved from `Microsoft.App/environments` to **`Microsoft.DBforPostgreSQL/flexibleServers`** (Container Apps Environment is on subnet 4). Subnet 5 is reserved for the platform PostgreSQL Flexible Server.
- **Parallel pre-reqs** — After `validate_and_setup`, `pre_req_*` jobs (DNS links, AAD groups, app registrations, route tables, NSGs) all start together. Network jobs are self-contained (set-resource-names → resolve contributor → create RGs → deploy) so they are not gated behind a separate `init` job. `landing_zone` deploys the spoke VNet only, then parallel **Deploy Azure Services** jobs (`azure_document_intelligence`, `azure_container_apps`, `azure_postgres`, …) each depend on `landing_zone`. Add future Azure services the same way. `Create-PlatformResourceGroups` retries transient conflicts when RT/NSG jobs ensure RGs concurrently.

### Fixed

- **App registration create race** — After creating a new Entra app, owner list/add and admin-consent grant reads can briefly return `Request_ResourceNotFound` while Graph replicates. Those calls now retry with backoff; consent also waits for a resolvable service principal id and URL-encodes the `oauth2PermissionGrants` filter.

## [1.4.0] - 2026-09-25

### Added

- **Internal Container Apps Environment** — Optional. Set `containerAppsEnvironment` to a subnet key (e.g. `subnet4`) in instance `core.yaml` to deploy an internal-only Azure Container Apps environment into the APP resource group (requires `APP` in `platformResourceGroups`). The value selects which VNet subnet hosts the environment (must be delegated to `Microsoft.App/environments`). Creates a dedicated Log Analytics workspace, private DNS zone for the environment default domain (spoke VNet linked), and triggers hub private DNS linking. The environment is deployed with a **system-assigned managed identity** (required for `registryIdentity: system-environment` ACR pulls). Set to `none` or omit to skip.
- **Container Apps storage account** — Optional companion to the CAE. Set `containerAppsStorage: true` to provision a hardened StorageV2 account (STO naming, **public network disabled**, file private endpoint on the PEP subnet, DNS A record in `privatelink.file.core.windows.net` via the same SetDnsRecords path as Document Intelligence) in the APP RG for apps to create Azure Files shares against later. Does **not** create file shares or CAE storage registrations — those stay with app-deploy so new apps do not require a platform re-run. Omit or set `false` to skip.

### Fixed

- **CAE system-assigned identity** — Container Apps Environment is now deployed as a native `Microsoft.App/managedEnvironments` resource with `identity.type: SystemAssigned` (SharedDefra `app.managed-environment` has no managed-identity parameter, so platform redeploys cleared identity and broke `registryIdentity: system-environment` ACR pulls). Outputs `systemAssignedIdentityPrincipalId` for AcrPull grants.
- **Arm-ttk 409 during lint** — PipelineCommon pin moved from `refs/tags/1.2.0` (arm-ttk download from a public Azure blob that now returns `409 Public access is not permitted`) to `refs/tags/1.2.1` on main, which pulls arm-ttk from GitHub releases (#159).

## [1.3.1] - 2026-09-24

### Added

- **Naming role code `AIP`** — Allowed role value **Automated Intelligence Platform** in `resources/naming-convention/naming-convention.bicep`, so resource groups and other named resources can use the AIP role segment (for example platform RGs).

## [1.3.0] - 2026-09-18

### Added

- **Entra app registrations** — Optional instance manifest `app-registration.json` in `plt-config`. The pipeline runs the ADP `Add-AdAppRegistrations` script when the file is present and skips the step when it is not. Graph authentication uses the same entra SP client id/secret as Entra group creation. Display names are tokenised from config (including `-#{{ instanceNumber }}`). Manifest `owners` are added without removing existing owners.

## [1.2.0] - 2026-09-17

### Added

- **Second Container Apps subnet** — Layout 1 now delegates **subnet 4** to **`Microsoft.App/environments`**, in addition to subnet 5. The seven-subnet template therefore provides two Container Apps–ready subnets without a separate manual delegation step.

## [1.1.0] - 2026-04-24

### Added

- **`additionalDnsZonesToLink`** — Optional. Supply a JSON string listing private DNS zones that should be **linked to the hub networks** during platform deploy (in addition to zones the framework already manages). Use a JSON array of objects with **`PrivateDnsZoneName`** and **`ResourceGroupName`** (property names are case-insensitive). You may still pass a legacy array of **zone name strings**; those are resolved using your region’s DNS resource group from the existing regional mapping. Omit the variable, set it to `[]`, or leave it empty to skip this step entirely.
- **Container Apps–ready networking** — The shared virtual network template can delegate the appropriate subnet to **`Microsoft.App/environments`**, so that subnet can host Azure Container Apps environments without a separate manual delegation step.

### Changed

- **Triggered CCoE pipelines** (private DNS zone linking and VNet peering) now report success and failure more reliably in Azure Pipelines: build completion is detected in a way that tolerates different API casing, and the job exit code reflects a failed remote run when `TF_BUILD` is set (including when the agent reports `True` rather than `true`). When a triggered **external** pipeline run does **not** succeed, the framework now downloads that run’s logs, bundles them, and **publishes them to your job as a pipeline artifact**. This provides visibility of the run result without having access to remote pipeline (typically CCoE managed).

## [1.0.0] - 2026-03-25

### Added

- Initial revision.
