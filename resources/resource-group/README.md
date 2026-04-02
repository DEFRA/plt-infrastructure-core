# Resource Group Module

A Bicep module that creates an Azure Resource Group using the naming convention module to generate the name.

## Purpose

This module creates a resource group with a name that follows the standard naming convention pattern. It calls the `naming-convention` module internally to generate the correct name.

## Important: Deployment Scope

**Resource groups must be deployed at subscription scope**, not resource group scope. The file that calls this module must have `targetScope = 'subscription'`.

## Parameters

All parameters match the naming convention module parameters, plus:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `subType` | string | Yes | Sub Type (3-4 characters). See naming-convention module for valid values. |
| `svc` | string | Yes | Service code (3 characters). See naming-convention module for valid values. |
| `role` | string | Yes | Role code (3 characters). Use "INF" for heterogeneous resource groups. See naming-convention module for valid values. |
| `deploymentEnvInstance` | string | Yes | Deployment Environment instance number (1 digit, 0-9) |
| `regionCode` | string | Yes | Region code (1 digit, e.g., 4 for UK South, 0 for Europe North) |
| `instanceNumber` | string | Yes | Instance number within the region (2 digits, 00-99) |
| `location` | string | Yes | The Azure region where the resource group will be created (e.g., "UK South") |
| `tags` | object | No | Additional tags to apply to the resource group. Default: empty object |
| `createdDate` | string | No | Date in the format yyyy-MM-dd. Default: current date |
| `deploymentDate` | string | No | Date in the format yyyyMMdd-HHmmss. Default: current date |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `name` | string | The name of the created resource group |
| `location` | string | The location of the resource group |
| `resourceId` | string | The resource ID of the resource group |
| `tags` | object | The tags applied to the resource group |

## Usage Example

```bicep
// This file must be deployed at subscription scope
targetScope = 'subscription'

module resourceGroup 'resource-group.bicep' = {
  name: 'resource-group-deployment'
  params: {
    subType: 'PRD'
    svc: 'CHM'
    role: 'INF'              // Infrastructure - for heterogeneous resource groups
    deploymentEnvInstance: '1'
    regionCode: '4'          // UK South
    instanceNumber: '01'
    location: 'UK South'
    tags: {
      // Optional additional tags
    }
  }
}

// Use the resource group name in other deployments
output resourceGroupName string = resourceGroup.outputs.name
```

## Role Selection for Resource Groups

According to the naming convention documentation:
- For Resource Groups containing **heterogeneous resource types**, use role code **"INF"** (Infrastructure)
- For Resource Groups containing **specific resource types**, use the appropriate role code (e.g., "DNS" for DNS Zones, "NET" for Network resources)

## Tags

The module automatically applies:
- Default tags from `default-tags.json`
- Location
- CreatedDate
- Environment (from subType)
- Purpose: "Resource Group"
- Any additional tags provided via the `tags` parameter

## Notes

- The resource group name is automatically generated using the naming convention module
- The module validates all naming convention parameters
- Resource groups are created at subscription scope
- The generated name follows the pattern: `<Sub Type><Svc><Role><RGP><Deployment Environment instance number><Region+Instance Number>`
