@description('Required. The name of the virtual network (derived from naming convention).')
param name string

@description('Required. Address prefixes for the virtual network (array of CIDR strings)')
param addressPrefixes array

@description('Optional. DNS servers for the virtual network (array of IP addresses)')
param dnsServers array = []

@description('Required. The subnets object.')
param subnets array

@allowed([
  'UKSouth'
])
@description('Required. The Azure region where the resources will be deployed.')
param location string

@description('Required. Environment name.')
param environment string

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
  Environment: environment
  Purpose: 'ADP-VIRTUAL-NETWORK'
}
var tags = union(loadJsonContent('../../default-tags.json'), commonTags)

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
    subnets: subnets
  }
}

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
