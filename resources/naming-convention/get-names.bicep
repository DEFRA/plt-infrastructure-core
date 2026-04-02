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

@description('Optional. Private link zone suffix (e.g. privatelink.cognitiveservices.azure.com). When set with privateLinkZoneResType, outputs privateLinkZoneName and privateLinkZoneResourceName.')
param privateLinkZoneSuffix string = ''

@description('Optional. Resource type code for the zone prefix (e.g. ADI, KVT). When set with privateLinkZoneSuffix, outputs privateLinkZoneName and privateLinkZoneResourceName.')
param privateLinkZoneResType string = ''

@description('Optional. Subnet name configs: array of {resType, instanceNumber}. When set, outputs subnetNames array. Config provides suffix (resType) per subnet; instanceNumber is 01, 02, etc.')
param subnetNameConfigs array = []

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

// Get route table name using naming convention (instance number omitted here; hard coded in route-table.bicep)
module routeTableNaming './naming-convention.bicep' = {
  name: 'rt-naming-${uniqueString(deployment().name)}'
  params: {
    subType: subType
    svc: svc
    role: 'NET'
    resType: 'RT'
    deploymentEnvInstance: deploymentEnvInstance
    regionCode: regionCode
    instanceNumber: '00' // placeholder; stripped below so route-table.bicep can append as appropriate
    toLower: false
  }
}
// Name without instance number (last 2 chars); route-table.bicep appends instance 01
var nameLen = length(routeTableNaming.outputs.name)
var routeTableNameWithoutInstance = nameLen > 2 ? substring(routeTableNaming.outputs.name, 0, nameLen - 2) : routeTableNaming.outputs.name

// Subnet naming: one module per subnet config. Config provides resType (suffix) per subnet; instanceNumber is 01, 02, etc.
module subnetNaming './naming-convention.bicep' = [for i in range(0, length(subnetNameConfigs)): {
  name: 'subnet-${i}-${uniqueString(deployment().name, subnetNameConfigs[i].resType, subnetNameConfigs[i].instanceNumber)}'
  params: {
    subType: subType
    svc: svc
    role: 'NET'
    resType: subnetNameConfigs[i].resType
    deploymentEnvInstance: deploymentEnvInstance
    regionCode: regionCode
    instanceNumber: subnetNameConfigs[i].instanceNumber
    toLower: false
  }
}]

// Optional: get private link DNS zone name (prefix from naming convention + suffix). Caller passes suffix (from config) and resType (pipeline knows which type, e.g. ADI).
module privateLinkZoneNaming './naming-convention.bicep' = if (!empty(privateLinkZoneSuffix) && !empty(privateLinkZoneResType)) {
  name: 'pdz-naming-${uniqueString(deployment().name, privateLinkZoneSuffix, privateLinkZoneResType)}'
  params: {
    subType: subType
    svc: svc
    role: 'INF'
    resType: privateLinkZoneResType
    deploymentEnvInstance: deploymentEnvInstance
    regionCode: regionCode
    instanceNumber: instanceNumber
    toLower: false
  }
}

// Outputs
output resourceGroupName string = resourceGroupNaming.outputs.name
output virtualNetworkName string = virtualNetworkNaming.outputs.name
output routeTableName string = routeTableNameWithoutInstance
output subnetNames array = [for i in range(0, length(subnetNameConfigs)): subnetNaming[i].outputs.name]
output privateLinkZoneName string = !empty(privateLinkZoneSuffix) && !empty(privateLinkZoneResType) ? '${privateLinkZoneNaming.outputs.name}.${privateLinkZoneSuffix}' : ''
// Generic resource name (prefix) for the private link zone. Concrete pipelines map this to their variable (e.g. documentIntelligenceResourceName).
output privateLinkZoneResourceName string = !empty(privateLinkZoneSuffix) && !empty(privateLinkZoneResType) ? privateLinkZoneNaming.outputs.name : ''
