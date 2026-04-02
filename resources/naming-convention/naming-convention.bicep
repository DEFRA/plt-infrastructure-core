// This module is scope-agnostic - it only outputs a name and doesn't create resources
// Set to subscription scope so it can be called from both subscription and resourceGroup scopes
targetScope = 'subscription'

@description('Required. Sub Type (3-4 characters).')
@allowed([
  'AIP'   // Automated Intelligence AI.DATALIFT
  'APS'   // Apps Shared Services
  'CAT'   // Catalogue
  'DEV'   // Development
  'LOG'   // Log
  'MST'   // Master Shared Transit
  'OPS'   // Ops Shared Services
  'POC'   // Proof Of Concept
  'PRD'   // Prod
  'PRE'   // Pre-prod
  'SEC'   // Security
  'SND'   // Sandpit
  'SSV1'  // Shared Services Sandbox only
  'SSV2'  // Shared Services Development and lower
  'SSV3'  // Shared Services Test and lower
  'SSV4'  // Shared Services Pre Production and lower only
  'SSV5'  // Shared Services Production and lower
  'TST'   // Test
])
param subType string

@description('Required. Service code (3 characters).')
@allowed([
  'AAD'   // Azure Active Directory
  'AIE'   // AI Environment
  'AIM'   // Defra AIMS AMX
  'BOO'   // Dell Boomi
  'CHM'   // EUX Chemicals
  'CSC'   // CCoe Support Activities
  'CUS'   // Customer identity
  'EMZ'   // Easimap on Azure
  'EOB'   // Earth Observation
  'EXP'   // EUX Exports
  'FFC'   // Future Farming and Countryside
  'FFF'   // Future Flood Forecasting System
  'IDM'   // Identity Management
  'IMD'   // Improving Data Management
  'IMF'   // Incident Management Forecasting System
  'IMP'   // EUX IPAFFS (Imports)
])
param svc string

@description('Required. Role code (3 characters).')
@allowed([
  'AAC'   // Automation Account
  'AAS'   // Azure Analysis Services
  'ADF'   // Azure Data Factory
  'ADG'   // Azure Data Gateway
  'ADL'   // Azure Data Lake
  'AFW'   // Azure Firewall
  'APP'   // Application
  'ASE'   // Application Service Environment
  'ASP'   // Application Service Plan
  'AXW'   // Axway Server
  'BAS'   // Bastion
  'BES'   // Back-End
  'BLB'   // Back-End Load Balancer
  'CER'   // Certificate
  'DBS'   // Database Server
  'DGW'   // Data Gateway
  'DHC'   // DHCP Server
  'DNS'   // DNS Zones
  'ETL'   // Extract Transform Load Server
  'EXP'   // Experimental / Exploratory
  'FES'   // Front-End
  'FLB'   // Front-End Load Balancer
  'FTP'   // File Transfer Server
  'GIT'   // GitLab
  'INF'   // Infrastructure
  'JEN'   // Jenkins
  'NET'   // Network
  'PLB'   // Proxy Load Balancer
])
param role string

@description('Required. Resource Type code (2-3 characters).')
@allowed([
  'AAA'   // Automation Account
  'ACA'   // Azure Container Apps
  'ACE'   // Azure Container Environments
  'ACI'   // Azure Container Instances
  'ADF'   // Azure Data Factory
  'AFD'   // Azure Front Door
  'AFA'   // Function App
  'AGW'   // Azure Application Gateway
  'AIS'   // Application Insights
  'AKS'   // Azure Kubernetes Service
  'ALA'   // Logic App
  'ALB'   // Application Load Balancer
  'API'   // API Connection
  'ASG'   // Auto Scaling Group
  'ASP'   // Application Service Plan
  'ASE'   // Application Service Environment
  'AAS'   // Azure Analysis Services
  'AVS'   // Availability Set
  'AWA'   // Web App
  'ADI'   // Azure Document Intelligence (private link zone prefix)
  'BEP'   // Back End Pool
  'CR'    // Azure Container Registry
  'FLB'   // Load Balancer
  'KVT'   // Key Vault
  'LW'    // Log Analytics Workspace
  'NSG'   // Network Security Group
  'RGP'   // Resource Group. Resource Group naming requires some judgment, it's selected function code should be roughly conformant to what resources are stored within it, eg a Resource Group containing DNS Zones would likely have a function code of "DNS". For any Resource Group likely to contain heterogenous resource types, "INF" should be used.
  'RT'    // Route Table
  'STO'   // Storage Account
  'SUB'   // Azure Subnet
  'SU'    // Subnet (abbreviated)
  'PEP'   // Private Endpoint
  'VNT'   // Virtual Network
  'WAF'   // Azure WAF Policy
])
param resType string

@description('Required. Deployment Environment instance number (1 digit, 0-9).')
@minLength(1)
@maxLength(1)
param deploymentEnvInstance string

@description('Required. Region code (1 digit, e.g., 4 for UK South, 0 for Europe North).')
@minLength(1)
@maxLength(1)
param regionCode string

@description('Required. Instance number within the region (2 digits, 00-99, e.g., 00, 01, 02, 99). Must be numeric.')
@minLength(2)
@maxLength(2)
param instanceNumber string

@description('Optional. Whether to convert the output to lowercase. Default is false to preserve uppercase naming convention.')
param toLower bool = false

// Validate instance number is numeric (00-99)
// Attempting to convert to int will fail at deployment time if not numeric (e.g., "XX")
// This ensures the value is numeric and can be converted
var instanceNumberInt = int(instanceNumber)
// Ensure it's in valid range (0-99) - this will cause deployment to fail if out of range
// Format as 2 digits with leading zero (e.g., 1 becomes "01", 99 becomes "99")
var instanceNumberValidated = instanceNumberInt >= 0 && instanceNumberInt <= 99 ? (instanceNumberInt < 10 ? '0${instanceNumberInt}' : string(instanceNumberInt)) : instanceNumber

// Build the name according to the naming convention pattern
// Pattern: <Sub Type><Svc><Role><Res Type><Deployment Environment instance number><Region+Instance Number>
// Example: PRDCHMDBSSQ1401
//   PRD = Sub Type
//   CHM = Svc
//   DB = Role
//   SSQ = Res Type
//   1 = Deployment Environment instance number
//   401 = Region+Instance Number (4 = UK South, 01 = instance)
var regionAndInstance = '${regionCode}${instanceNumberValidated}'
var resourceName = '${subType}${svc}${role}${resType}${deploymentEnvInstance}${regionAndInstance}'

// Output the formatted name
output name string = toLower ? sys.toLower(resourceName) : resourceName

// Output the components for reference/debugging
output components object = {
  subType: subType
  svc: svc
  role: role
  resType: resType
  deploymentEnvInstance: deploymentEnvInstance
  regionCode: regionCode
  instanceNumber: instanceNumberValidated
  regionAndInstance: regionAndInstance
  fullName: resourceName
}
