@description('Required. Container Apps Environment settings. Must contain name. Optional workloadProfiles (defaults to Consumption).')
param containerAppsEnvironment object

@description('Required. Log Analytics workspace settings. Must contain name. Optional skuName (defaults to PerGB2018).')
param logAnalytics object

@description('Required. Virtual network for internal integration. Must contain name, resourceGroup and subnetContainerApps.')
param vnet object

@description('Required. Sub type (e.g. SND, PRD).')
param subType string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Restrict the environment to internal (VNet) ingress only. Only internal is supported by this template.')
@allowed([
  true
])
param internal bool = true

@description('Optional. Boolean value to enable or disable resource lock.')
param resourceLockEnabled bool = false

@description('Optional. Date in the format yyyyMMdd-HHmmss.')
param deploymentDate string = utcNow('yyyyMMdd-HHmmss')

@description('Optional. Date in the format yyyy-MM-dd.')
param createdDate string = utcNow('yyyy-MM-dd')

var commonTags = {
  Location: location
  CreatedDate: createdDate
  Environment: subType
}

var defaultTags = union(loadJsonContent('../../default-tags.json'), commonTags)

var logAnalyticsSkuName = contains(logAnalytics, 'skuName') && !empty(logAnalytics.skuName) ? logAnalytics.skuName : 'PerGB2018'

var workloadProfiles = contains(containerAppsEnvironment, 'workloadProfiles') && !empty(containerAppsEnvironment.workloadProfiles)
  ? containerAppsEnvironment.workloadProfiles
  : [
      {
        workloadProfileType: 'Consumption'
      }
    ]

var infrastructureSubnetId = resourceId(
  vnet.resourceGroup,
  'Microsoft.Network/virtualNetworks/subnets',
  vnet.name,
  vnet.subnetContainerApps
)

var dockerBridgeCidr = '172.16.0.1/28'
var infrastructureResourceGroupName = take('${containerAppsEnvironment.name}_ME', 63)

module logAnalyticsWorkspace 'br/SharedDefraRegistry:operational-insights.workspace:0.4.3' = {
  name: 'log-analytics-${deploymentDate}'
  params: {
    name: logAnalytics.name
    location: location
    skuName: logAnalyticsSkuName
    lock: resourceLockEnabled ? 'CanNotDelete' : null
    tags: union(defaultTags, {
      Name: logAnalytics.name
      Purpose: 'Log Analytics Workspace'
    })
  }
}

module managedEnvironment 'br/SharedDefraRegistry:app.managed-environment:0.4.10' = {
  name: 'container-apps-environment-${deploymentDate}'
  params: {
    enableDefaultTelemetry: false
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
    name: containerAppsEnvironment.name
    dockerBridgeCidr: dockerBridgeCidr
    infrastructureSubnetId: infrastructureSubnetId
    internal: internal
    location: location
    lock: resourceLockEnabled ? {
      kind: 'CanNotDelete'
      name: '${containerAppsEnvironment.name}-CanNotDelete'
    } : null
    workloadProfiles: workloadProfiles
    zoneRedundant: false
    infrastructureResourceGroupName: infrastructureResourceGroupName
    tags: union(defaultTags, {
      Name: containerAppsEnvironment.name
      Purpose: 'Container Apps Environment'
    })
  }
}

var defaultDomain = toLower(managedEnvironment.outputs.defaultDomain)
var staticIp = managedEnvironment.outputs.staticIp

module privateDnsZone 'br/SharedDefraRegistry:network.private-dns-zone:0.5.2' = {
  name: 'container-apps-environment-dns-${deploymentDate}'
  params: {
    name: defaultDomain
    tags: union(defaultTags, {
      Name: defaultDomain
      Purpose: 'Container Apps Environment Private DNS Zone'
    })
    virtualNetworkLinks: [
      {
        name: vnet.name
        virtualNetworkResourceId: resourceId(vnet.resourceGroup, 'Microsoft.Network/virtualNetworks', vnet.name)
        registrationEnabled: false
        tags: union(defaultTags, {
          Name: vnet.name
          Purpose: 'Container Apps Environment Private DNS Zone VNet Link'
        })
      }
    ]
    a: [
      {
        name: '*'
        ttl: 3600
        aRecords: [
          {
            ipv4Address: staticIp
          }
        ]
      }
    ]
  }
}

output name string = containerAppsEnvironment.name
output defaultDomain string = defaultDomain
output staticIp string = staticIp
output logAnalyticsWorkspaceName string = logAnalytics.name
output privateDnsZoneName string = defaultDomain
