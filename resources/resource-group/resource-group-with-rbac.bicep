targetScope = 'subscription'

@description('Required. The name of the resource group (derived from naming convention).')
param name string

@description('Required. The Azure region where the resource group will be created (e.g., UK South)')
param location string

@description('Optional. Sub Type (3-4 characters, e.g., SSV5, PRD, DEV) - used for tagging only.')
param subType string = ''

@description('Optional. Tags to apply to the resource group.')
param tags object = {}

@description('Optional. Date in the format yyyy-MM-dd.')
param createdDate string = utcNow('yyyy-MM-dd')

@description('Optional. AD Group Object ID to assign Contributor role. If not provided, no role assignment will be created.')
param adGroupObjectId string = ''

@description('Optional. Contributor role definition ID. Default is the built-in Contributor role.')
param contributorRoleDefinitionId string = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

// Step 1: Create the resource group
module resourceGroupModule './resource-group.bicep' = {
  name: 'resource-group-${uniqueString(deployment().name)}'
  params: {
    name: name
    location: location
    subType: subType
    tags: tags
    createdDate: createdDate
  }
}

// Step 2: Assign Contributor role to AD Group (if provided)
// Deploy role assignment module scoped to the resource group
module roleAssignmentModule './rg-role-assignment.bicep' = if (!empty(adGroupObjectId)) {
  name: 'role-assignment-${uniqueString(deployment().name, adGroupObjectId)}'
  scope: resourceGroup(subscription().subscriptionId, name)
  params: {
    adGroupObjectId: adGroupObjectId
    roleDefinitionId: contributorRoleDefinitionId
    principalType: 'Group'
  }
  dependsOn: [
    resourceGroupModule
  ]
}

// Outputs
output resourceGroupName string = resourceGroupModule.outputs.name
output resourceGroupLocation string = resourceGroupModule.outputs.location
output resourceGroupId string = resourceGroupModule.outputs.resourceId
output resourceGroupTags object = resourceGroupModule.outputs.tags
@description('Role assignment ID if created')
output roleAssignmentId string = !empty(adGroupObjectId) ? (roleAssignmentModule != null ? roleAssignmentModule.outputs.roleAssignmentId : '') : ''
