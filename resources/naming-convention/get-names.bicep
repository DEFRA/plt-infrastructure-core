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

@description('Optional. Private link zone suffix (e.g. privatelink.cognitiveservices.azure.com). When set with privateLinkZoneResType, outputs privateLinkZoneName.')
param privateLinkZoneSuffix string = ''

@description('Optional. Resource type code for the zone prefix (e.g. ADI for Azure Document Intelligence). When set with privateLinkZoneSuffix, outputs privateLinkZoneName.')
param privateLinkZoneResType string = ''

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

// Optional: get private link DNS zone name (prefix from naming convention + suffix, e.g. SNDAIEINFADI1401.privatelink.cognitiveservices.azure.com)
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
output privateLinkZoneName string = !empty(privateLinkZoneSuffix) && !empty(privateLinkZoneResType) ? '${privateLinkZoneNaming.outputs.name}.${privateLinkZoneSuffix}' : ''
// Document Intelligence resource name (same naming as private link zone prefix); derived when privateLinkZoneResType is set.
output documentIntelligenceResourceName string = !empty(privateLinkZoneSuffix) && !empty(privateLinkZoneResType) ? privateLinkZoneNaming.outputs.name : ''
