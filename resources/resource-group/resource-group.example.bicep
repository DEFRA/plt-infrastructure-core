// Example usage of the resource-group module
// Note: This must be deployed at subscription scope, not resource group scope

targetScope = 'subscription'

@description('Required. Sub Type (3-4 characters).')
param subType string = 'PRD'

@description('Required. Service code (3 characters).')
param svc string = 'CHM'

@description('Required. Role code (3 characters).')
param role string = 'INF'  // Infrastructure - for heterogeneous resource groups

@description('Required. Deployment Environment instance number (1 digit).')
param deploymentEnvInstance string = '1'

@description('Required. Region code (1 digit).')
param regionCode string = '4'  // UK South

@description('Required. Instance number (2 digits).')
param instanceNumber string = '01'

@description('Required. The Azure region where the resource group will be created.')
param location string = 'UK South'

// Create the resource group
module resourceGroup 'resource-group.bicep' = {
  name: 'resource-group-deployment'
  params: {
    subType: subType
    svc: svc
    role: role
    deploymentEnvInstance: deploymentEnvInstance
    regionCode: regionCode
    instanceNumber: instanceNumber
    location: location
    tags: {
      // Optional additional tags
    }
  }
}

// Outputs
output resourceGroupName string = resourceGroup.outputs.name
output resourceGroupLocation string = resourceGroup.outputs.location
output resourceGroupId string = resourceGroup.outputs.resourceId
