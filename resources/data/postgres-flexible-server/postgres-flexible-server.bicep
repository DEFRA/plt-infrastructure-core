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

@description('Optional. Platform Key Vault name. When set, stores POSTGRES-HOST / POSTGRES-USER / POSTGRES-PASSWORD (ADP pattern).')
param keyVaultName string = ''

@description('Optional. Local admin login required when passwordAuth is Enabled. Can only be set at create (or when enabling password auth).')
param administratorLogin string = 'psqladmin'

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
var skuName = !empty(server.?skuName) ? server.?skuName! : 'Standard_B1ms'
var tier = !empty(server.?tier) ? server.?tier! : 'Burstable'
var storageSizeGB = server.?storageSizeGB ?? 32
var postgresVersion = !empty(server.?version) ? server.?version! : '16'
var highAvailability = !empty(server.?highAvailability) ? server.?highAvailability! : 'Disabled'
// AVM: -1 = no availability zone (required for Burstable / non-zonal SKUs).
var availabilityZone = server.?availabilityZone ?? -1

var adminIdentityName = take('${serverName}-dbadmin', 128)
// Server-scoped zone (not the centrally managed privatelink.postgres.database.azure.com) so CCoE hub linking is allowed.
// Azure FQDN becomes {server}.{zone}, e.g. sndaieapppsq1401.sndaieapppsq1401.privatelink.postgres.database.azure.com
var privateDnsZoneName = '${serverName}.privatelink.postgres.database.azure.com'
var serverFqdn = '${serverName}.${privateDnsZoneName}'

// Password auth requires admin credentials (EngineCredentialsNotProvided otherwise).
// Stable across redeploys so platform runs do not rotate the password unexpectedly.
// Complexity: upper + lower + digit + special (Azure Flexible Server policy).
var administratorLoginPassword = 'P${toUpper(take(uniqueString(resourceGroup().id, serverName, 'pg-admin'), 8))}${take(uniqueString(serverName, 'pg-admin-pw'), 8)}9!'

var hasCaeAdmin = !empty(containerAppsEnvironmentEntraAdmin.objectId) && !empty(containerAppsEnvironmentEntraAdmin.principalName)
var hasKeyVault = !empty(keyVaultName)

// Flexible Server Entra admin `objectId` for a user-assigned MI is the clientId (AVM / ADP pattern).
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

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = if (hasKeyVault) {
  name: keyVaultName
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
// Entra + password auth: admin login/password required by Azure when passwordAuth is Enabled.
// Platform UAMI (+ optional CAE MI) remain Entra admins for DB automation.
// Uses public AVM (not SharedDefra) so PostgreSQL 16+ is in the version allow-list.
module flexibleServer 'br/avm:db-for-postgre-sql/flexible-server:0.16.1' = {
  name: 'postgres-flexible-server-${deploymentDate}'
  params: {
    name: serverName
    location: location
    version: postgresVersion
    tier: tier
    skuName: skuName
    storageSizeGB: storageSizeGB
    highAvailability: highAvailability
    availabilityZone: availabilityZone
    createMode: 'Default'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
    }
    enableTelemetry: false
    lock: resourceLockEnabled ? {
      kind: 'CanNotDelete'
    } : null
    backupRetentionDays: 7
    geoRedundantBackup: 'Disabled'
    publicNetworkAccess: 'Disabled'
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
}

resource secretPostgresHost 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = if (hasKeyVault) {
  name: 'POSTGRES-HOST'
  parent: keyVault
  properties: {
    value: serverFqdn
  }
  dependsOn: [
    flexibleServer
  ]
}

resource secretPostgresUser 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = if (hasKeyVault) {
  name: 'POSTGRES-USER'
  parent: keyVault
  properties: {
    value: administratorLogin
  }
  dependsOn: [
    flexibleServer
  ]
}

resource secretPostgresPassword 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = if (hasKeyVault) {
  name: 'POSTGRES-PASSWORD'
  parent: keyVault
  properties: {
    value: administratorLoginPassword
  }
  dependsOn: [
    flexibleServer
  ]
}

output name string = serverName
output fqdn string = serverFqdn
output privateDnsZoneName string = privateDnsZoneName
output administratorLogin string = administratorLogin
output adminManagedIdentityName string = adminIdentityName
output adminManagedIdentityPrincipalId string = aadAdminUserMi.outputs.principalId
output adminManagedIdentityClientId string = aadAdminUserMi.outputs.clientId
