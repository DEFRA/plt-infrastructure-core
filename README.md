# plt-infrastructure-core

Uses Azure DevOps to deploy, connect, and configure a routable spoke network according to Defra standards into an existing subscription.

The deployment takes configuration from `DEFRA/plt-config` to tune the deployment.

The following non-network resources may also be deployed according to Defra patterns:

- Entra ID Groups and memberships.
- Document Intelligence
- DNS
- Resource Groups and permissions.

The deployment provides clear access boundaries as follows:

- `Network/Infrastructure Resource Group` - Readable by application teams. Permissions allow identities to join the associated VNets (typically identity would be a separate deployment pipeline).

- `Application Resource Group(s)` - One or many Resource Groups may be deployed (using list `platformResourceGroups`). This component is responsible for deploying the Resource Groups and setting RBAC only, and not managing the resources within. Consuming teams are able to manage the resources within.


## How it’s deployed today

- **Pipeline**: `.azuredevops/deploy-platform-core-env.yaml`
- **Config source**: `DEFRA/plt-config` (pulled in as a pipeline repository resource)
- **Config selection**:
  - `applicationID` (e.g. `aie`)
  - `instance` (e.g. `01`)


## Environment/Location

`environmentName` (e.g. `snd4`) and `location` (e.g. `uksouth`) are used to select the regional files. These values are available in config, so supplying them as pipeline parameters duplicates the source of truth. This is driven by how/when ADO resolves variable values and certain restrictions imposed by consuming the `ado-pipeline-common` framework. The target architecture is for these values to be derived and supplied by the wrapper job. For the current architecture, the pipeline validates consistency between the two sources of values and aborts if differences are detected.

## How it will be deployed in future

The design intention is a wrapper job to automatically identify when a file in `DEFRA/plt-config` has changed and inject the file(s) into this pipeline.

## Configuration (plt-config)

The pipeline loads variables from the following, in order (later entries override earlier ones):

- `plt-config/config/common.yaml`
- `plt-config/config/regional/<environmentName>-<location>.yaml`
- `plt-config/config/<applicationID>/<instance>/core.yaml`

See [plt-config](https://github.com/DEFRA/plt-config) for the configuration file format and supported variables.

## Key scripts

Located under `scripts/pipeline/`:

- `Create-PlatformResourceGroups.ps1`: Creates platform RGs and applies RBAC (Contributor) to the configured Entra group.
- `Invoke-CreateAadGroups.ps1` / `Create-AADGroups.ps1`: Creates Entra groups from the config manifest.
- `Resolve-NetworkJoinGroup.ps1`: Resolves `networkJoinGroupName` to object id for VNet role assignment.
- `Resolve-EntraGroupByDisplayName.ps1`: Shared helper to resolve Entra group display names to object ids (used where directory lookups are needed).
- `SetDnsRecords.ps1`: Unified DNS record updater for both `additionalDnsConfig` entries and Document Intelligence private endpoint DNS.
- `Validate-Params-Match-Config.ps1`: Validates pipeline `environmentName` matches config (`subType + deploymentEnvInstance`) and validates `location`.
- `Validate-AdditionalDnsConfigJson.ps1`: Validates `additionalDnsConfig` JSON when Document Intelligence is enabled.

Shared helper scripts live under:

- `scripts/common-scripts/PowerShellLibrary/`: DNS helper scripts used by pipeline steps (e.g. `Set-PrivateDnsRecordSet.ps1`).

## Repo layout (high level)

- `.azuredevops/`: Azure DevOps pipeline definitions
- `resources/`: Bicep/ARM templates and parameter templates
- `scripts/`: pipeline and helper scripts used during deployment

## Notes

- **Template validation** is run as part of the shared pipeline framework. Resource-group scoped validation requires a resource group name to be supplied; the deployment flow overrides placeholder values during the real deployment steps.
- **Release management**: tag this repository using [Semantic Versioning](https://semver.org/) (for example `1.2.3`) and update `CHANGELOG.md` for every release.
