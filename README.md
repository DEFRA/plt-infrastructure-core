# plt-infrastructure-core

Core “platform landing zone” infrastructure for Defra subscriptions, deployed via Azure DevOps.

This repo contains the Bicep/ARM templates and pipeline scripts to create platform resource groups, networking, and shared services (as enabled per environment config).

## How it’s deployed

- **Pipeline**: `.azuredevops/deploy-platform-core-env.yaml`
- **Config source**: `DEFRA/plt-config` (pulled in as a pipeline repository resource)
- **Config selection**:
  - `applicationID` (e.g. `aie`)
  - `instance` (e.g. `01`)
  - `environmentName` (e.g. `snd4`) and `location` (e.g. `uksouth`) for regional variables

## Configuration (plt-config)

The pipeline loads variables from:

- `plt-config/config/common.yaml`
- `plt-config/config/<applicationID>/<instance>/core.yaml`
- `plt-config/config/regional/<environmentName>-<location>.yaml`

Legacy in-repo `/vars` files are no longer used and have been removed.

Key values typically defined in `core.yaml`:

- `subType`, `serviceCode`, `deploymentEnvInstance`, `regionCode`, `instanceNumber`
- `subscriptionName`, `subscriptionId`
- `platformResourceGroups` (e.g. `EXP,APP`)
- `networkJoinGroupName` and `appRgContributor` (Entra group display names)
- `documentIntelligenceSku` and optional `additionalDnsConfig`

## Key scripts

Located under `scripts/pipeline/`:

- `Create-PlatformResourceGroups.ps1`: Creates platform RGs and applies RBAC (Contributor) to the configured Entra group.
- `Invoke-CreateAadGroups.ps1` / `Create-AADGroups.ps1`: Creates Entra groups from the config manifest.
- `Resolve-NetworkJoinGroup.ps1`: Resolves `networkJoinGroupName` to object id for VNet role assignment.
- `Resolve-EntraGroupByDisplayName.ps1`: Shared helper to resolve Entra group display names to object ids (used where directory lookups are needed).
- `Validate-Params-Match-Config.sh`: Validates pipeline `environmentName` matches config (`subType + deploymentEnvInstance`) and validates `location`.
- `Validate-AdditionalDnsConfigJson.sh`: Validates `additionalDnsConfig` JSON when Document Intelligence is enabled.

Shared helper scripts live under:

- `scripts/common-scripts/PowerShellLibrary/`: DNS helper scripts used by pipeline steps (e.g. `Set-PrivateDnsRecordSet.ps1`).

## Repo layout (high level)

- `.azuredevops/`: Azure DevOps pipeline definitions
- `resources/`: Bicep/ARM templates and parameter templates
- `scripts/`: pipeline and helper scripts used during deployment

## Notes

- **Template validation** is run as part of the shared pipeline framework. Resource-group scoped validation requires a resource group name to be supplied; the deployment flow overrides placeholder values during the real deployment steps.
- **Release management**: tag this repository using [Semantic Versioning](https://semver.org/) (for example `1.2.3`) and update `CHANGELOG.md` for every release.
