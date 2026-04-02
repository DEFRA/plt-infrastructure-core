using 'log-analytics-workspace.bicep'

param logAnalytics = {
  name: '#{{ logAnalyticsWorkspace }}'
  skuName: '#{{ logAnalyticsWorkspaceSku }}'
}

param location = '#{{ location }}'

param subType = '#{{ subType }}'

param resourceLockEnabled = #{{ resourceLockEnabled }}
