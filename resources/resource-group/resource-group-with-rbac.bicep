targetScope = 'subscription'

@description('Required. Sub Type (3-4 characters, e.g., SSV5, PRD, DEV)')
param subType string

@description('Required. Service code (3 characters, e.g., AIE, AAD)')
param svc string

@description('Required. Role code (3 characters, use INF for heterogeneous resource groups)')
param role string

@description('Required. Deployment Environment instance number (1 digit, 0-9)')
param deploymentEnvInstance string

@description('Required. Region code (1 digit, e.g., 4 for UK South, 0 for Europe North)')
param regionCode string

@description('Required. Instance number within the region (2 digits, 00-99)')
param instanceNumber string

@description('Required. The Azure region where the resource group will be created (e.g., UK South)')
param location string

@description('Optional. Tags to apply to the resource group.')
param tags object = {}

@description('Optional. Date in the format yyyy-MM-dd.')
param createdDate string = utcNow('yyyy-MM-dd')

@description('Optional. AD Group Object ID to assign Contributor role. If not provided, no role assignment will be created.')
param adGroupObjectId string = ''

@description('Optional. Contributor role definition ID. Default is the built-in Contributor role.')
param contributorRoleDefinitionId string = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

// Step 1: Get the resource group name using the naming convention module
module namingConvention '../naming-convention/naming-convention.bicep' = {
  name: 'naming-convention-${uniqueString(deployment().name)}'
  params: {
    subType: subType
    svc: svc
    role: role
    resType: 'RGP'
    deploymentEnvInstance: deploymentEnvInstance
    regionCode: regionCode
    instanceNumber: instanceNumber
  }
}

// Step 2: Create the resource group
module resourceGroupModule './resource-group.bicep' = {
  name: 'resource-group-${uniqueString(deployment().name)}'
  params: {
    name: namingConvention.outputs.name
    location: location
    subType: subType
    tags: tags
    createdDate: createdDate
  }
}

// Step 3: Assign Contributor role to AD Group (if provided)
// This needs to be deployed at resource group scope
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(adGroupObjectId)) {
  name: guid(resourceGroupModule.outputs.resourceId, adGroupObjectId, contributorRoleDefinitionId)
  scope: resourceGroupModule.outputs.resourceId
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: adGroupObjectId
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
output roleAssignmentId string = !empty(adGroupObjectId) ? roleAssignment.id : ''
