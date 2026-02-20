@description('Required. The Route Table object. name = base from naming (e.g. RT-XXX); suffix 01/02/03 is appended from routeTableSuffix.')
param routeTable object
@description('Suffix for this template (01 = default, 02, 03 = alternate route tables).')
param routeTableSuffix string = '01'
@description('Routes for this route table (defined in the template JSON).')
param routes array
@allowed([
  'UKSouth'
])
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
  Purpose: 'ADP-ROUTE-TABLE'
}
var tags = union(loadJsonContent('../../default-tags.json'), commonTags)

var routeTableName = '${routeTable.name}${routeTableSuffix}'

module route 'br/SharedDefraRegistry:network.route-table:0.4.2' = {
  name: 'route-table-${deploymentDate}'
  params: {
    name: routeTableName
    lock: lockEnabled ? 'CanNotDelete' : null
    location: location
    tags: tags
    disableBgpRoutePropagation: true
    routes: routes
  }
}

