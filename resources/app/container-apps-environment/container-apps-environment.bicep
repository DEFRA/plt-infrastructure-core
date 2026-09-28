@description('Required. Container Apps Environment settings. Must contain name. Optional workloadProfiles (defaults to Consumption).')
param containerAppsEnvironment object

@description('Required. Log Analytics workspace settings. Must contain name. Optional skuName (defaults to PerGB2018).')
param logAnalytics object

@description('Required. Virtual network for internal integration. Must contain name, resourceGroup and subnetContainerApps. Optional subnetPrivateEndpoints when provisioning Azure Files private endpoint.')
param vnet object

@description('Optional. Azure Files storage account for the environment. Set enabled to true (with accountName) to provision a hardened StorageV2 account for apps to create shares against later. Does not create file shares or CAE storage registrations.')
param storage object = {
  accountName: ''
  skuName: 'Standard_LRS'
  enabled: false
}

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

var storageEnabledRaw = contains(storage, 'enabled') ? storage.enabled : false
var storageEnabled = storageEnabledRaw == true || contains(['true', '1', 'yes'], toLower('${storageEnabledRaw}'))
var enableStorage = storageEnabled && !empty(storage.accountName)
var storageAccountName = toLower(storage.accountName)
var storageSkuName = contains(storage, 'skuName') && !empty(storage.skuName) ? storage.skuName : 'Standard_LRS'
var storagePrivateEndpointName = take('${storageAccountName}pep01', 64)

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

// Module does not output staticIp; read it from the deployed environment (same pattern as ADP DNS zone).
resource managedEnvironmentResource 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: containerAppsEnvironment.name
  dependsOn: [
    managedEnvironment
  ]
}

var defaultDomain = toLower(managedEnvironment.outputs.defaultDomain)
var staticIp = managedEnvironmentResource.properties.staticIp

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

// --- Optional hardened storage account for Container Apps (shares/mounts are app-deploy concern) ---
// Public access disabled (policy); private endpoint + DNS A record (same pattern as Document Intelligence).
module storageAccountModule 'br/SharedDefraRegistry:storage.storage-account:0.5.3' = if (enableStorage) {
  name: 'container-apps-storage-${deploymentDate}'
  params: {
    name: storageAccountName
    location: location
    skuName: storageSkuName
    kind: 'StorageV2'
    lock: resourceLockEnabled ? 'CanNotDelete' : null
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    privateEndpoints: [
      {
        name: storagePrivateEndpointName
        service: 'file'
        subnetResourceId: resourceId(vnet.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', vnet.name, vnet.subnetPrivateEndpoints)
        tags: union(defaultTags, {
          Name: storagePrivateEndpointName
          Purpose: 'Container Apps Azure Files private endpoint'
        })
      }
    ]
    tags: union(defaultTags, {
      Name: storageAccountName
      Purpose: 'Container Apps Environment Azure Files'
    })
  }
}

output name string = containerAppsEnvironment.name
output defaultDomain string = defaultDomain
output staticIp string = staticIp
output logAnalyticsWorkspaceName string = logAnalytics.name
output privateDnsZoneName string = defaultDomain
output storageAccountName string = enableStorage ? storageAccountName : ''
output storagePrivateEndpointName string = enableStorage ? storagePrivateEndpointName : ''
