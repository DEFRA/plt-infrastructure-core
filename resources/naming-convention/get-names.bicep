targetScope = 'subscription'

@description('Required. Sub Type (3-4 characters, e.g., SSV5, PRD, DEV)')
param subType string

@description('Required. Service code (3 characters, e.g., AIE, AAD)')
param svc string

@description('Required. Role code (3 characters, use INF for heterogeneous resource groups)')
param role string

@description('Required. Deployment Environment instance number (1 digit, 0-9)')
param deploymentEnvInstance string

@description('Required. Region code (1 digit, e.g., 4 for UK South, 0 for Europe North)')
param regionCode string

@description('Required. Instance number within the region (2 digits, 00-99)')
param instanceNumber string

// Get resource group name using naming convention
module resourceGroupNaming './naming-convention.bicep' = {
  name: 'rg-naming-${uniqueString(deployment().name)}'
  params: {
    subType: subType
    svc: svc
    role: role
    resType: 'RGP'
    deploymentEnvInstance: deploymentEnvInstance
    regionCode: regionCode
    instanceNumber: instanceNumber
    toLower: false
  }
}

// Get virtual network name using naming convention
module virtualNetworkNaming './naming-convention.bicep' = {
  name: 'vnet-naming-${uniqueString(deployment().name)}'
  params: {
    subType: subType
    svc: svc
    role: 'NET'
    resType: 'VNT'
    deploymentEnvInstance: deploymentEnvInstance
    regionCode: regionCode
    instanceNumber: instanceNumber
    toLower: false
  }
}

// Outputs
output resourceGroupName string = resourceGroupNaming.outputs.name
output virtualNetworkName string = virtualNetworkNaming.outputs.name
