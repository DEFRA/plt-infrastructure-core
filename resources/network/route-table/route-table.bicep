@description('Required. The Route Table object. name from naming-convention module (without instance); instance 01 is appended in this template.')
param routeTable object
@allowed([
  'UKSouth'
])
@description('Required. The Azure region where the resources will be deployed.')
param location string
@description('Required. Environment name.')
param environment string
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
  Environment: environment
  Purpose: 'ADP-ROUTE-TABLE'
}
var tags = union(loadJsonContent('../../default-tags.json'), commonTags)

// Instance number 01 hard coded (naming module omits it for route table)
var routeTableName = '${routeTable.name}01'

module route 'br/SharedDefraRegistry:network.route-table:0.4.2' = {
  name: 'route-table-${deploymentDate}'
  params: {
    name: routeTableName
    lock: lockEnabled ? 'CanNotDelete' : null
    location: location
    tags: tags
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'Default'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: routeTable.virtualApplicanceIp
        }
      }
      {
        name: 'Active_Directory_to_Internet'
        properties: {
          addressPrefix: 'AzureActiveDirectory'
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

