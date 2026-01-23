targetScope = 'resourceGroup'

@description('Required. AD Group Object ID to assign the role to.')
param adGroupObjectId string

@description('Required. Role definition ID (full resource ID).')
param roleDefinitionId string

@description('Optional. Principal type. Default is Group.')
param principalType string = 'Group'

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, adGroupObjectId, roleDefinitionId)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: adGroupObjectId
    principalType: principalType
  }
}

output roleAssignmentId string = roleAssignment.id
