---

---
# Get-ResourcePrivateEndPointsDnsRecordsAsJson documentation

## Short description

Get IP Addresses and their associated FQDN and location.

## Long description

The *Get-ResourcePrivateEndPointsDnsRecordsAsJson.ps1* script gets IP addresses and their associated FQDN and location by supplying a resource group and resource name and returns a JSON object to the variable PrivateDnsRecordsJson.  This PrivateDnsRecordsJson variable value is required by the *Set-PrivateDnsRecordSet.ps1* which has to be run after this script.  More details on the Set-PrivateDnsRecordSet.ps1 script can be found in [Set-PrivateDnsRecordSet.md](Set-PrivateDnsRecordSet.md).  It is also included in the YAML example at the end of this document.

## PrivateDnsRecordsJson storage blob example

```PrivateDnsRecordsJson storage blob example
{
    "Region": "northeurope",
    "Fqdn": "devcdoinfst1004.blob.core.windows.net",
    "IpAddress": [
        "10.105.62.22"
    ]
}
```

## PrivateDnsRecordsJson multi region cosmos example

```PrivateDnsRecordsJson multi region cosmos example
[
    {
        "Region": "westeurope",
        "Fqdn": "devcdoinfcosmos1001.documents.azure.com",
        "IpAddress": [
            "10.205.90.36"
        ]
    },
    {
        "Region": "westeurope",
        "Fqdn": "devcdoinfcosmos1001-northeurope.documents.azure.com",
        "IpAddress": [
            "10.205.90.37"
        ]
    },
    {
        "Region": "westeurope",
        "Fqdn": "devcdoinfcosmos1001-westeurope.documents.azure.com",
        "IpAddress": [
            "10.205.90.38"
        ]
    },
    {
        "Region": "northeurope",
        "Fqdn": "devcdoinfcosmos1001.documents.azure.com",
        "IpAddress": [
            "10.105.62.23"
        ]
    },
    {
        "Region": "northeurope",
        "Fqdn": "devcdoinfcosmos1001-northeurope.documents.azure.com",
        "IpAddress": [
            "10.105.62.25"
        ]
    },
    {
        "Region": "northeurope",
        "Fqdn": "devcdoinfcosmos1001-westeurope.documents.azure.com",
        "IpAddress": [
            "10.105.62.26"
        ]
    }
]
```

## Syntax

```powershell
Get-ResourcePrivateEndPointsDnsRecordsAsJson.ps1 
 -ResourceGroupName <String> 
 -ResourceName <String> 
```

## Parameters

### -ResourceGroupName

The Resource Group containing the Resource.

### -ResourceName

The Resource Name

## Pipeline example

This example shows how to run the script as part of post-deployment script from the `common-infrastructure-deploy.yaml`.  The Get-ResourcePrivateEndPointsDnsRecordsAsJson.ps1 goes hand in hand with
the Set-PrivateDnsRecordSet.ps1 script which is also detailed in the example below.  Please refer to the [Set-PrivateDnsRecordSet.md](Set-PrivateDnsRecordSet.md) file for details of the Set-PrivateDnsRecordSet.ps1

```yaml
postDeployScriptsList:
  - displayName: Resolve Private Endpoint IP Addresses
    scriptPath: 'Get-ResourcePrivateEndPointsDnsRecordsAsJson.ps1@PipelineCommon'
    ScriptArguments: >
      -ResourceGroupName $(resourceGroupName)
      -ResourceName $(resourceName  )
```

## Full Pipeline example

```yaml

extends:
  template: /templates/pipelines/common-infrastructure-deploy.yaml@PipelineCommon
  parameters:
    projectName: SAMPLE
    groupedTemplates:
      - name: create_or_update_private_dns_records_examples
        templates:
          - name: storage
            path: bicep-templates
            type: 'bicep'
            scope: "Resource Group"
            resourceGroupName: $(resourceGroupName)
            postDeployServiceConnectionVariableName: azureResourceManagerConnection
            postDeployScriptsList:
              - displayName: Resolve Private Endpoint IP for $(storageAccountName)
                scriptPath: 'Get-ResourcePrivateEndPointsDnsRecordsAsJson.ps1@PipelineCommon'
                ScriptArguments: >
                  -ResourceGroupName $(resourceGroupName)
                  -ResourceName $(storageAccountName)
              - displayName: Set DNS record for $(storageAccountName)
                scriptPath: 'Set-PrivateDnsRecordSet.ps1@PipelineCommon'
                serviceConnectionVariableName: mstAzureResourceManagerConnection

```

## Post deploy script example

```yaml Post deploy script example with optional Ttl parameter

postDeployScriptsList:
  - displayName: Resolve Private Endpoint IP for $(keyvaultName)
  scriptPath: 'Get-ResourcePrivateEndPointsDnsRecordsAsJson.ps1@PipelineCommon'
  ScriptArguments: >
    -ResourceGroupName $(resourceGroupName)
    -ResourceName $(keyvaultName)
  - displayName: Set DNS record for $(keyvaultName)
  scriptPath: 'Set-PrivateDnsRecordSet.ps1@PipelineCommon'
  serviceConnectionVariableName: mstAzureResourceManagerConnection
  ScriptArguments: >
    -Ttl 120

```