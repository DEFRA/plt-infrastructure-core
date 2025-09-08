@description('Required. The VNET Infra object as JSON string.')
param vnet string
var vnetObj = json(vnet)

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
    name: vnetObj.name
    location: location
    lock: lockEnabled ? 'CanNotDelete' : null
    tags: tags
    enableDefaultTelemetry: true
    addressPrefixes: vnetObj.addressPrefixes
    dnsServers: vnetObj.dnsServers
    subnets: subnets
  }
}
