@description('Required. The parameter object for the virtual network. The object must contain the name, resourceGroup and subnetPrivateEndpoints values.')
param vnet object

@description('Required. The parameter object for AI Document Intelligence. The object must contain the name and sku values.')
param aiDocumentIntelligence object

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Restrict outbound network access.')
param restrictOutboundNetworkAccess bool = false

@description('Required. Sub type (e.g. SND, PRD).')
param subType string

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

var documentIntelligenceTags = {
  Name: aiDocumentIntelligence.name
  Purpose: 'AI Document Intelligence'
}

// Private DNS zone creation/linking removed (blocked by policy). Private endpoint IP is output for use in a subsequent DNS update.
module documentIntelligenceResource 'br/avm:cognitive-services/account:0.8.0' = {
  name: 'ai-document-intelligence-${deploymentDate}'
  params: {
    kind: 'FormRecognizer'
    name: aiDocumentIntelligence.name
    publicNetworkAccess: 'Disabled'
    location: location
    sku: aiDocumentIntelligence.sku
    customSubDomainName: aiDocumentIntelligence.customSubDomainName
    restrictOutboundNetworkAccess: restrictOutboundNetworkAccess
    disableLocalAuth: aiDocumentIntelligence.disableLocalAuth
    managedIdentities: {
      systemAssigned: true
    }
    privateEndpoints: [
      {
        subnetResourceId: resourceId(vnet.resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', vnet.name, vnet.subnetPrivateEndpoints)
      }
    ]
    tags: union(defaultTags, documentIntelligenceTags)
  }
}

// Private endpoint IP for subsequent DNS update (e.g. add A record to existing zone). Pipeline can consume this output.
output privateEndpointIpAddress string = documentIntelligenceResource.outputs.privateEndpoints[0].customDnsConfig[0].ipAddresses[0]

