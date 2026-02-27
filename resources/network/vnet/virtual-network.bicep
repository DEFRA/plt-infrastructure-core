@description('Required. The name of the virtual network (derived from naming convention).')
param name string

@description('Required. Address prefixes for the virtual network (array of CIDR strings)')
param addressPrefixes array

@description('Optional. DNS servers for the virtual network (array of IP addresses)')
param dnsServers array = []

@description('Required. The subnets object.')
param subnets array

@allowed([
  'uksouth'
])
@description('Required. The Azure region where the resources will be deployed (lowercase short name, e.g. uksouth).')
param location string

@description('Required. Sub type (e.g. SND, PRD).')
param subType string

@description('Required. Boolean (as string) to enable or disable resource lock. Accepts true/false/1/0/yes/no.')
param resourceLockEnabled string
var lockEnabled = contains(['true', '1', 'yes'], toLower(resourceLockEnabled))

@description('Optional. Date in the format yyyy-MM-dd.')
param createdDate string = utcNow('yyyy-MM-dd')

@description('Optional. Date in the format yyyyMMdd-HHmmss.')
param deploymentDate string = utcNow('yyyyMMdd-HHmmss')

@description('Optional. AD Group Object ID to grant Network Contributor (network join) on the VNet. Resolved from networkJoinGroupName in config.')
param networkJoinGroupObjectId string = ''

var commonTags = {
  Location: location
  CreatedDate: createdDate
  Environment: subType
  Purpose: 'ADP-VIRTUAL-NETWORK'
}
var tags = union(loadJsonContent('../../default-tags.json'), commonTags)

// Route tables are deployed from numbered templates (route-table/1/, 2/, 3/) by the pipeline. Subnets reference them inline (subnetNRouteTableResourceId from config).
var subnetsForVNet = [for i in range(0, length(subnets)): {
  name: subnets[i].name
  addressPrefix: subnets[i].addressPrefix
  privateEndpointNetworkPolicies: subnets[i].privateEndpointNetworkPolicies ?? 'Enabled'
  privateLinkServiceNetworkPolicies: subnets[i].privateLinkServiceNetworkPolicies ?? 'Enabled'
  serviceEndpoints: subnets[i].serviceEndpoints ?? []
  delegations: contains(subnets[i], 'delegations') && length(subnets[i].delegations) > 0 ? subnets[i].delegations : []
}]

module virtualNetwork 'br/SharedDefraRegistry:network.virtual-network:0.4.2' = {
  name: 'virtual-network-${deploymentDate}'
  params: {
    name: name
    location: location
    lock: lockEnabled ? 'CanNotDelete' : null
    tags: tags
    enableDefaultTelemetry: true
    addressPrefixes: addressPrefixes
    dnsServers: dnsServers
    subnets: subnetsForVNet
  }
}

// Apply each subnet from JSON (including routeTable when defined inline); batchSize(1) to avoid Azure 429
var subnetDelegations = [for i in range(0, length(subnets)): contains(subnets[i], 'delegations') && length(subnets[i].delegations) > 0 ? subnets[i].delegations : []]
@sys.batchSize(1)
resource subnetAssociations 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = [for i in range(0, length(subnets)): {
  parent: vnetExisting
  name: subnets[i].name
  properties: {
    addressPrefix: subnets[i].addressPrefix
    privateEndpointNetworkPolicies: subnets[i].privateEndpointNetworkPolicies ?? 'Enabled'
    privateLinkServiceNetworkPolicies: subnets[i].privateLinkServiceNetworkPolicies ?? 'Enabled'
    serviceEndpoints: subnets[i].serviceEndpoints ?? []
    routeTable: contains(subnets[i], 'routeTable') && subnets[i].routeTable != null && !empty(subnets[i].routeTable.id) ? subnets[i].routeTable : null
    delegations: subnetDelegations[i]
  }
  dependsOn: [ virtualNetwork ]
}]

// Grant Ability to join the VNet to the configured group
var networkContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7eabc9a4-85f7-4f71-b8ab-75daaccc1033')
resource vnetExisting 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: name
}
resource networkJoinRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(networkJoinGroupObjectId)) {
  scope: vnetExisting
  name: guid(vnetExisting.id, networkJoinGroupObjectId, networkContributorRoleId)
  properties: {
    roleDefinitionId: networkContributorRoleId
    principalId: networkJoinGroupObjectId
    principalType: 'Group'
  }
  dependsOn: [ virtualNetwork ]
}
