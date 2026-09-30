@description('Required. PostgreSQL Flexible Server settings. Must contain name. Optional skuName (defaults to Standard_B1ms), tier (Burstable), storageSizeGB (32), version (16).')
param server object

@description('Required. Virtual network. Must contain name, resourceGroup and subnetPostgreSql (delegated to Microsoft.DBforPostgreSQL/flexibleServers).')
param vnet object

@description('Required. Sub type (e.g. SND, PRD).')
param subType string

@description('Optional. When set, also grants this principal Entra admin on the server (e.g. CAE system-assigned MI) for in-VNet DB automation.')
param containerAppsEnvironmentEntraAdmin object = {
  objectId: ''
  principalName: ''
}

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

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

var serverName = toLower(server.name)
var skuName = contains(server, 'skuName') && !empty(server.skuName) ? server.skuName : 'Standard_B1ms'
var tier = contains(server, 'tier') && !empty(server.tier) ? server.tier : 'Burstable'
var storageSizeGB = contains(server, 'storageSizeGB') && !empty(server.storageSizeGB) ? server.storageSizeGB : 32
var postgresVersion = contains(server, 'version') && !empty(server.version) ? server.version : '16'
var highAvailability = contains(server, 'highAvailability') && !empty(server.highAvailability) ? server.highAvailability : 'Disabled'

var adminIdentityName = take('${serverName}-dbadmin', 128)
var privateDnsZoneName = 'privatelink.postgres.database.azure.com'

var hasCaeAdmin = !empty(containerAppsEnvironmentEntraAdmin.objectId) && !empty(containerAppsEnvironmentEntraAdmin.principalName)

// Flexible Server Entra admin `objectId` for a user-assigned MI is the clientId (SharedDefra / ADP pattern).
// For a CAE system-assigned MI, pass the principalId from the environment identity.
var entraAdministrators = concat(
  [
    {
      objectId: aadAdminUserMi.outputs.clientId
      principalName: aadAdminUserMi.outputs.name
      principalType: 'ServicePrincipal'
    }
  ],
  hasCaeAdmin
    ? [
        {
          objectId: containerAppsEnvironmentEntraAdmin.objectId
          principalName: containerAppsEnvironmentEntraAdmin.principalName
          principalType: 'ServicePrincipal'
        }
      ]
    : []
)

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnet.name
  scope: resourceGroup(vnet.resourceGroup)
}

resource postgresSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: virtualNetwork
  name: vnet.subnetPostgreSql
}

module aadAdminUserMi 'br/SharedDefraRegistry:managed-identity.user-assigned-identity:0.4.3' = {
  name: 'postgres-aad-admin-mi-${deploymentDate}'
  params: {
    name: adminIdentityName
    location: location
    lock: resourceLockEnabled ? 'CanNotDelete' : null
    tags: union(defaultTags, {
      Name: adminIdentityName
      Purpose: 'PostgreSQL Flexible Server Entra admin (platform DB automation)'
    })
  }
}

module privateDnsZone 'br/SharedDefraRegistry:network.private-dns-zone:0.5.2' = {
  name: 'postgres-private-dns-${deploymentDate}'
  params: {
    name: privateDnsZoneName
    tags: union(defaultTags, {
      Name: privateDnsZoneName
      Purpose: 'PostgreSQL Flexible Server Private DNS Zone'
    })
    virtualNetworkLinks: [
      {
        name: vnet.name
        virtualNetworkResourceId: virtualNetwork.id
        registrationEnabled: false
        tags: union(defaultTags, {
          Name: vnet.name
          Purpose: 'PostgreSQL Flexible Server Private DNS Zone VNet Link'
        })
      }
    ]
  }
}

// Private VNet injection (delegated subnet) — no public endpoint.
// Entra auth enabled; password auth disabled. Platform UAMI (+ optional CAE MI) are Entra admins
// so app-deploy can create per-app databases later without a shared password.
module flexibleServer 'br/SharedDefraRegistry:db-for-postgre-sql.flexible-server:0.4.4' = {
  name: 'postgres-flexible-server-${deploymentDate}'
  params: {
    name: serverName
    location: location
    version: postgresVersion
    tier: tier
    skuName: skuName
    storageSizeGB: storageSizeGB
    highAvailability: highAvailability
    createMode: 'Default'
    activeDirectoryAuth: 'Enabled'
    passwordAuth: 'Disabled'
    enableDefaultTelemetry: false
    lock: resourceLockEnabled ? 'CanNotDelete' : null
    backupRetentionDays: 7
    geoRedundantBackup: 'Disabled'
    administrators: entraAdministrators
    configurations: []
    databases: []
    firewallRules: []
    delegatedSubnetResourceId: postgresSubnet.id
    privateDnsZoneArmResourceId: privateDnsZone.outputs.resourceId
    tags: union(defaultTags, {
      Name: serverName
      Purpose: 'Platform PostgreSQL Flexible Server'
    })
  }
  dependsOn: [
    aadAdminUserMi
  ]
}

output name string = serverName
output fqdn string = '${serverName}.postgres.database.azure.com'
output privateDnsZoneName string = privateDnsZoneName
output adminManagedIdentityName string = adminIdentityName
output adminManagedIdentityPrincipalId string = aadAdminUserMi.outputs.principalId
output adminManagedIdentityClientId string = aadAdminUserMi.outputs.clientId
