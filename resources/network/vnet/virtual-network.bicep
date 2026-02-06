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

@description('Optional. Route table base name (from naming module); when set with routeTableVirtualApplianceIp, deploys route table and assigns to subnet1 in this deployment.')
param routeTableName string = ''

@description('Optional. Firewall virtual appliance IP for route table default route; required when routeTableName is set.')
param routeTableVirtualApplianceIp string = ''

var commonTags = {
  Location: location
  CreatedDate: createdDate
  Environment: environment
  Purpose: 'ADP-VIRTUAL-NETWORK'
}
var tags = union(loadJsonContent('../../default-tags.json'), commonTags)

// Deploy route table in same deployment as VNet when both routeTableName and routeTableVirtualApplianceIp are provided
var deployRouteTable = !empty(routeTableName) && !empty(routeTableVirtualApplianceIp)
var routeTableResourceName = '${routeTableName}01'
var routeTableTags = union(loadJsonContent('../../default-tags.json'), { Location: location, CreatedDate: createdDate, Environment: environment, Purpose: 'ADP-ROUTE-TABLE' })

module routeTable 'br/SharedDefraRegistry:network.route-table:0.4.2' = if (deployRouteTable) {
  name: 'route-table-${deploymentDate}'
  params: {
    name: routeTableResourceName
    lock: lockEnabled ? 'CanNotDelete' : null
    location: location
    tags: routeTableTags
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'Default'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: routeTableVirtualApplianceIp
        }
      }
      {
        name: 'Active_Directory_to_Internet'
        properties: {
          addressPrefix: 'AzureActiveDirectory'
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

// When route table is deployed, attach it to subnet1 (first subnet)
var routeTableId = deployRouteTable ? resourceId('Microsoft.Network/routeTables', routeTableResourceName) : ''
var subnetsForVNet = deployRouteTable && length(subnets) > 0
  ? concat(
      [ union(subnets[0], { routeTable: { id: routeTableId } }) ],
      skip(subnets, 1)
    )
  : subnets

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
  dependsOn: deployRouteTable ? [ routeTable ] : []
}

// Associate route table with all subnets (shared VNet module may not forward routeTable on subnets)
var subnetIndicesForRouteTable = deployRouteTable ? range(0, length(subnets)) : []
// Delegations: only from subnet object (config); no default – must be passed when required
resource subnetRouteTableAssociations 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = [for i in subnetIndicesForRouteTable: {
  parent: vnetExisting
  name: subnets[i].name
  properties: {
    addressPrefix: subnets[i].addressPrefix
    privateEndpointNetworkPolicies: subnets[i].privateEndpointNetworkPolicies ?? 'Enabled'
    privateLinkServiceNetworkPolicies: subnets[i].privateLinkServiceNetworkPolicies ?? 'Enabled'
    serviceEndpoints: subnets[i].serviceEndpoints ?? []
    routeTable: { id: routeTableId }
    delegations: contains(subnets[i], 'delegations') && length(subnets[i].delegations) > 0 ? subnets[i].delegations : []
  }
  dependsOn: [ virtualNetwork, routeTable ]
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
