// Creates the private DNS zone for Azure Document Intelligence (e.g. *.privatelink.cognitiveservices.azure.com).
// Zone name and resource group come from config/naming (documentIntelligencePrivateLinkZoneName, dnsResourceGroup).
targetScope = 'resourceGroup'

@description('Name of the private DNS zone (e.g. from naming convention: SNDAIEINFADI1401.privatelink.cognitiveservices.azure.com).')
param name string

@description('Optional. Tags for the private DNS zone.')
param tags object = {}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: name
  location: 'global'
  tags: tags
}

output name string = privateDnsZone.name
output id string = privateDnsZone.id
