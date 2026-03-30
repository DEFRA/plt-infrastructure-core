@description('Required. The name of the virtual network (derived from naming convention).')
param name string

@description('Required. Address prefixes for the virtual network (array of CIDR strings)')
param addressPrefixes array

@description('Optional. DNS servers for the virtual network (array of IP addresses)')
param dnsServers array = []

@description('Required. The subnets object.')
param subnets array

@description('Required. Service code (3 characters) for naming, e.g. AIE, AAD.')
param svc string

@description('Required. Deployment Environment instance number (1 digit, 0-9).')
param deploymentEnvInstance string

@description('Required. Region code (1 digit, e.g. 4 for UK South, 0 for Europe North).')
param regionCode string

@description('Required. Base route table name prefix used to construct per-subnet route table resource IDs.')
param routeTableName string

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
  Purpose: 'SPOKE-VIRTUAL-NETWORK'
}
var tags = union(loadJsonContent('../../default-tags.json'), commonTags)

// Compute subnet names deterministically so Validate jobs don't require subnet{n}Name token placeholders.
// Naming convention used by subnetNaming in `get-names.bicep`:
//   <subType><svc><role:NET><resType:SUB><deploymentEnvInstance><regionCode><subnetInstanceNumber(2 digits)>
var subnetInstanceNumbers = [for i in range(0, length(subnets)): padLeft(string(i + 1), 2, '0')]
var subnetNames = [for i in range(0, length(subnets)): '${subType}${svc}NETSUB${deploymentEnvInstance}${regionCode}${subnetInstanceNumbers[i]}']

// Route tables are deployed from numbered templates (route-table/1/, 2/, 3/) by the pipeline.
// Subnets reference them inline either as:
//  - older contract: `{ "routeTable": { "id": "<fullResourceId>" } }`, or
//  - new contract: `{ "routeTable": { "routeTableNumber": "<0|1|2|3>" } }`.
// The new contract lets Validate avoid routeTableResourceId placeholders; we construct the ID from `routeTableName` + the suffix.
var subnetsForVNet = [for i in range(0, length(subnets)): {
  name: subnetNames[i]
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
  name: subnetNames[i]
  properties: {
    addressPrefix: subnets[i].addressPrefix
    privateEndpointNetworkPolicies: subnets[i].privateEndpointNetworkPolicies ?? 'Enabled'
    privateLinkServiceNetworkPolicies: subnets[i].privateLinkServiceNetworkPolicies ?? 'Enabled'
    serviceEndpoints: subnets[i].serviceEndpoints ?? []
    // routeTableNumber may arrive as an Integer (JSON literal) or string (from token replacement).
    // Avoid `empty()` because it doesn't support Integer types; treat null/blank as default to 1.
    routeTable: contains(subnets[i], 'routeTable') && subnets[i].routeTable != null ? (((subnets[i].routeTable.routeTableNumber == null || string(subnets[i].routeTable.routeTableNumber) == '') ? 1 : int(string(subnets[i].routeTable.routeTableNumber))) > 0 ? { id: resourceId('Microsoft.Network/routeTables', '${routeTableName}${padLeft(string((subnets[i].routeTable.routeTableNumber == null || string(subnets[i].routeTable.routeTableNumber) == '') ? 1 : int(string(subnets[i].routeTable.routeTableNumber))), 2, '0')}') } : null) : null
    // Default to NSG layout 1 when omitted/blank. If explicitly set to 0, no NSG is attached.
    networkSecurityGroup: (((subnets[i].nsgLayout == null || string(subnets[i].nsgLayout) == '') ? 1 : int(string(subnets[i].nsgLayout))) > 0) ? { id: resourceId('Microsoft.Network/networkSecurityGroups', '${subType}${svc}NETNSG${deploymentEnvInstance}${regionCode}${padLeft(string((subnets[i].nsgLayout == null || string(subnets[i].nsgLayout) == '') ? 1 : int(string(subnets[i].nsgLayout))), 2, '0')}') } : null
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
