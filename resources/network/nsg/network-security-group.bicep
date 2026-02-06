@description('Required. Object of the format The Network Security Group Name, Rules[Name,securityrules obj].')
param nsgList array = []

@description('Required. The Azure region where the resources will be deployed.')
param location string
@description('Required. Sub type (e.g. SND, PRD).')
param subType string
@description('Required. Boolean (as string) to enable or disable resource lock. Accepts true/false/1/0/yes/no.')
param resourceLockEnabled string
var lockEnabled = contains(['true', '1', 'yes'], toLower(resourceLockEnabled))
@description('Optional. Date in the format yyyy-MM-dd.')
param createdDate string = utcNow('yyyy-MM-dd')
@description('Optional. Date in the format yyyyMMdd-HHmmss.')
param deploymentDate string = utcNow('yyyyMMdd-HHmmss')

var commonTags = {
  Location: location
  CreatedDate: createdDate
  Environment: subType 
  Tier: 'Shared'
}
var tags = union(loadJsonContent('../../default-tags.json'), commonTags)

module networksecuritygroup 'br/SharedDefraRegistry:network.network-security-group:0.4.2' = [for nsg in nsgList:  {
  name: '${nsg.name}-${deploymentDate}'
  params: {
    name: nsg.name
    lock: lockEnabled ? 'CanNotDelete' : null
    location: location
    tags: union(tags, { Purpose: nsg.purpose})
    securityRules: nsg.securityRules 
  }
}]
