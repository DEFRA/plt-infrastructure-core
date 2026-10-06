# Changelog

All notable changes to this repository should be documented in this file.

## [1.4.0] - 2026-10-06

### Added

- **Container Apps Environment** — Optional internal CAE (`containerAppsEnvironment`, layout 1 subnet 4) with system-assigned MI, Log Analytics, and private DNS.
- **CAE storage** — Optional Standard SMB STO (`containerAppsStorage`) and Premium NFS STO (`containerAppsNfsStorage`, `Premium_LRS`, instanceNumber+1). Shares/CAE mounts remain product-deploy.
- **PostgreSQL Flexible Server** — Optional private Flex Server (`postgresFlexibleServer`, layout 1 subnet 5). Entra + password auth; optional `POSTGRES-*` secrets when `keyVault: true`.
- **Key Vault** — Optional private KVT (`keyVault: true`) with vault PE + DNS.
- **Naming** — `PSQ` / `KVT` / CAE / STO names via `get-names`; layout 1 subnet 5 delegated to PostgreSQL (CAE on subnet 4).

### Changed

- Parallel pre-req and Deploy Azure Services jobs after `landing_zone`.

### Fixed

- CAE system-assigned identity retained across redeploys; app-registration Graph race retries; arm-ttk pin for lint.

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
