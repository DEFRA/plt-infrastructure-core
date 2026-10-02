@description('Required. Key Vault settings. Must contain name. Optional skuName (standard|premium), enableSoftDelete, enablePurgeProtection, softDeleteRetentionInDays.')
param keyVault object

@description('Required. Virtual network. Must contain name, resourceGroup and subnetPrivateEndpoints.')
param vnet object

@description('Required. Sub type (e.g. SND, PRD).')
param subType string

@description('Optional. Entra group object id granted Key Vault Secrets Officer (e.g. appRgContributor). Empty skips the assignment.')
param secretsOfficerPrincipalId string = ''

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

var keyVaultName = keyVault.name
var skuName = !empty(keyVault.?skuName) ? keyVault.?skuName! : 'standard'
var enableSoftDelete = keyVault.?enableSoftDelete ?? true
// Default purge protection to match resource locks (on in locked envs); SND can override false.
var enablePurgeProtection = keyVault.?enablePurgeProtection ?? resourceLockEnabled
var softDeleteRetentionInDays = keyVault.?softDeleteRetentionInDays ?? 90
var privateEndpointName = take('${toLower(keyVaultName)}pep01', 64)

var hasSecretsOfficer = !empty(secretsOfficerPrincipalId)

var roleAssignments = hasSecretsOfficer
  ? [
      {
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
        description: 'App RG contributor group — manage secrets in the platform Key Vault'
        principalIds: [
          secretsOfficerPrincipalId
        ]
        principalType: 'Group'
      }
    ]
  : []

module vault 'br/SharedDefraRegistry:key-vault.vault:0.5.3' = {
  name: 'key-vault-${deploymentDate}'
  params: {
    name: keyVaultName
    location: location
    vaultSku: skuName
    lock: resourceLockEnabled ? 'CanNotDelete' : null
    enableRbacAuthorization: true
    enableSoftDelete: enableSoftDelete
    enablePurgeProtection: enablePurgeProtection
    softDeleteRetentionInDays: softDeleteRetentionInDays
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
    }
    publicNetworkAccess: 'Disabled'
    privateEndpoints: [
      {
        name: privateEndpointName
        service: 'vault'
        subnetResourceId: resourceId(vnet.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', vnet.name, vnet.subnetPrivateEndpoints)
        tags: union(defaultTags, {
          Name: privateEndpointName
          Purpose: 'Key Vault Private Endpoint'
        })
      }
    ]
    roleAssignments: roleAssignments
    tags: union(defaultTags, {
      Name: keyVaultName
      Purpose: 'Platform Key Vault'
    })
  }
}

output name string = keyVaultName
output resourceId string = vault.outputs.resourceId
output privateEndpointName string = privateEndpointName
