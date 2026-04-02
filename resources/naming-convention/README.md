# Naming Convention Module

A reusable Bicep module that generates resource names according to the standard naming convention pattern.

## Purpose

This module centralizes naming convention logic so that all other Bicep modules can use consistent naming without duplicating the naming pattern logic.

## Naming Pattern

The module generates names using the following pattern:

```
<Sub Type><Svc><Role><Res Type><Deployment Environment instance number><Region+Instance Number>
```

### Example: `PRDCHMDBSSQ1401`

Breaking down the example:
- `PRD` = Sub Type (3 chars) - Production
- `CHM` = Svc (3 chars) - Service code
- `DB` = Role (2 chars) - Role code
- `SSQ` = Res Type (3 chars) - SQL Server
- `1` = Deployment Environment instance number (1 digit)
- `401` = Region+Instance Number (3 digits)
  - `4` = Region code (UK South)
  - `01` = Instance number within region

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `subType` | string | Yes | Sub Type (3-4 characters). See valid values below. |
| `svc` | string | Yes | Service code (3 characters). See valid values below. |
| `role` | string | Yes | Role code (3 characters). See valid values below. |
| `resType` | string | Yes | Resource Type code (2-3 characters). See valid values below. |
| `deploymentEnvInstance` | string | Yes | Deployment Environment instance number (1 digit, 0-9) |
| `regionCode` | string | Yes | Region code (1 digit, e.g., `4` for UK South, `0` for Europe North) |
| `instanceNumber` | string | Yes | Instance number within the region (2 digits, 00-99, e.g., `00`, `01`, `02`, `99`) |
| `toLower` | bool | No | Whether to convert output to lowercase. Default: `false` (preserves uppercase convention) |

## Valid Sub Type Values

| Code | Description |
|------|-------------|
| `AIP` | Automated Intelligence AI.DATALIFT |
| `APS` | Apps Shared Services |
| `CAT` | Catalogue |
| `DEV` | Development |
| `LOG` | Log |
| `MST` | Master Shared Transit |
| `OPS` | Ops Shared Services |
| `POC` | Proof Of Concept |
| `PRD` | Prod |
| `PRE` | Pre-prod |
| `SEC` | Security |
| `SND` | Sandpit |
| `SSV1` | Shared Services Sandbox only |
| `SSV2` | Shared Services Development and lower |
| `SSV3` | Shared Services Test and lower |
| `SSV4` | Shared Services Pre Production and lower only |
| `SSV5` | Shared Services Production and lower |
| `TST` | Test |

## Valid Service Code Values

| Code | Description |
|------|-------------|
| `AAD` | Azure Active Directory |
| `AIE` | AI Environment |
| `AIM` | Defra AIMS AMX |
| `BOO` | Dell Boomi |
| `CHM` | EUX Chemicals |
| `CSC` | CCoe Support Activities |
| `CUS` | Customer identity |
| `EMZ` | Easimap on Azure |
| `EOB` | Earth Observation |
| `EXP` | EUX Exports |
| `FFC` | Future Farming and Countryside |
| `FFF` | Future Flood Forecasting System |
| `IDM` | Identity Management |
| `IMD` | Improving Data Management |
| `IMF` | Incident Management Forecasting System |
| `IMP` | EUX IPAFFS (Imports) |

## Valid Resource Type Code Values

| Code | Description |
|------|-------------|
| `AAA` | Automation Account |
| `ACA` | Azure Container Apps |
| `ACE` | Azure Container Environments |
| `ACI` | Azure Container Instances |
| `ADF` | Azure Data Factory |
| `AFD` | Azure Front Door |
| `AFA` | Function App |
| `AGW` | Azure Application Gateway |
| `AIS` | Application Insights |
| `AKS` | Azure Kubernetes Service |
| `ALA` | Logic App |
| `ALB` | Application Load Balancer |
| `API` | API Connection |
| `ASG` | Auto Scaling Group |
| `ASP` | Application Service Plan |
| `ASE` | Application Service Environment |
| `AAS` | Azure Analysis Services |
| `AVS` | Availability Set |
| `AWA` | Web App |
| `BEP` | Back End Pool |
| `CR` | Azure Container Registry |
| `FLB` | Load Balancer |
| `KVT` | Key Vault |
| `LW` | Log Analytics Workspace |
| `NSG` | Network Security Group |
| `RGP` | Resource Group* |
| `STO` | Storage Account |
| `SUB` | Azure Subnet |
| `WAF` | Azure WAF Policy |

## Valid Role Code Values

| Code | Description |
|------|-------------|
| `AAC` | Automation Account |
| `AAS` | Azure Analysis Services |
| `ADF` | Azure Data Factory |
| `ADG` | Azure Data Gateway |
| `ADL` | Azure Data Lake |
| `AFW` | Azure Firewall |
| `ASE` | Application Service Environment |
| `ASP` | Application Service Plan |
| `AXW` | Axway Server |
| `BAS` | Bastion |
| `BES` | Back-End |
| `BLB` | Back-End Load Balancer |
| `CER` | Certificate |
| `DBS` | Database Server |
| `DGW` | Data Gateway |
| `DHC` | DHCP Server |
| `DNS` | DNS Zones |
| `ETL` | Extract Transform Load Server |
| `EXP` | Exploratory |
| `FES` | Front-End |
| `FLB` | Front-End Load Balancer |
| `FTP` | File Transfer Server |
| `GIT` | GitLab |
| `INF` | Infrastructure |
| `JEN` | Jenkins |
| `NET` | Network |
| `PLB` | Proxy Load Balancer |

## Region Codes

| Code | Region |
|------|--------|
| `0` | Europe North |
| `4` | UK South |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `name` | string | The formatted resource name |
| `components` | object | The individual components for reference/debugging |

## Usage Example

```bicep
// Example: SQL Server in Production, UK South
module sqlServerName 'naming-convention.bicep' = {
  name: 'sql-server-naming'
  params: {
    subType: 'PRD'           // Production
    svc: 'CHM'              // Service code
    role: 'DB'               // Database role
    resType: 'SSQ'          // SQL Server
    deploymentEnvInstance: '1' // Environment instance
    regionCode: '4'          // UK South
    instanceNumber: '01'     // First instance
  }
}

// Output: PRDCHMDBSSQ1401

// Use the output in your resource
module sqlServer 'br/SharedDefraRegistry:sql.server:1.0.0' = {
  name: 'sql-server-deployment'
  params: {
    name: sqlServerName.outputs.name
    // ... other parameters
  }
}
```

## Resource Type Codes

Common resource type codes (3 characters):

- `SSQ` - SQL Server
- `STO` - Storage Account
- `OAI` - Open AI
- `VNT` - Virtual Network
- `NSG` - Network Security Group
- `LAW` - Log Analytics Workspace
- `PE` - Private Endpoint (may need padding to 3 chars)
- `MID` - Managed Identity

## Benefits

1. **Consistency**: Ensures all resources follow the same naming pattern
2. **Maintainability**: Update naming logic in one place
3. **Reusability**: Use across all Bicep modules
4. **Validation**: Built-in validation for instance number format
5. **Flexibility**: Supports optional suffixes for special cases
