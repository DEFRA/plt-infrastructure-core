targetScope = 'subscription'

@description('Required. The name of the resource group. Should be generated using the naming-convention module.')
param name string

@description('Required. The Azure region where the resource group will be created.')
param location string

@description('Optional. Sub Type (3-4 characters) for tagging purposes. Used to set the Environment tag.')
param subType string = ''

@description('Optional. Tags to apply to the resource group.')
param tags object = {}

@description('Optional. Date in the format yyyy-MM-dd.')
param createdDate string = utcNow('yyyy-MM-dd')

// Build tags
var commonTags = {
  Location: location
  CreatedDate: createdDate
  Purpose: 'Resource Group'
}
var environmentTag = !empty(subType) ? { Environment: subType } : {}
var defaultTags = union(loadJsonContent('../default-tags.json'), commonTags)
var resourceGroupTags = union(defaultTags, environmentTag, tags)

// Create the resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: name
  location: location
  tags: resourceGroupTags
}

// Outputs
output name string = resourceGroup.name
output location string = resourceGroup.location
output resourceId string = resourceGroup.id
output tags object = resourceGroup.tags
