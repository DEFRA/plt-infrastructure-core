---

---
# Set-PrivateDnsRecordSet documentation

## Short description

Create or update A records in Private DNS Zones

## Long description

The *Set-PrivateDnsRecordSet.ps1* script creates DNS records in Private DNS Zones.  It converts the PrivateDnsRecordsJson variable which is set in the Get-ResourcePrivateEndPointsDnsRecordsAsJson.ps1 script into a Powershell object and loops through each entry and creates or updates the A record in the appropriate Private DNS Zone in the correct region.  The script also utilises two mapping tables, one to obtain the correct region resource group for Private DNS Zones which is set in common vars and another to get the public DNS and Private DNS Name which is created dynamically.  The Set-PrivateDnsRecordSet.ps1 script is dependant on the Get-ResourcePrivateEndPointsDnsRecordsAsJson.ps1 script - more details can be found in [Get-ResourcePrivateEndPointsDnsRecordsAsJson.md](Get-ResourcePrivateEndPointsDnsRecordsAsJson.md).  The YAML example at the end of this page shows how to use both scripts together, as part of a pipeline.

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
Set-PrivateDnsRecordSet.ps1 
 -Ttl <int> OPTIONAL DEFAULTS TO 60 Seconds
```

## Parameters

### -Ttl

Time to live.  This is an OPTIONAL parameter and DEFAULTS to 60 Seconds

## Pipeline examples

This example shows how to run the script as part of post-deployment script from the `common-infrastructure-deploy.yaml`.  The Set-PrivateDnsRecordSet.ps1 goes hand in hand with
the Get-ResourcePrivateEndPointsDnsRecordsAsJson.ps1 script which is also detailed in the example below.  Please refer to the [Get-ResourcePrivateEndPointsDnsRecordsAsJson.md](Get-ResourcePrivateEndPointsDnsRecordsAsJson.md) file for details of the Get-ResourcePrivateEndPointsDnsRecordsAsJson.ps1

## full example

```yaml full example

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
                ScriptArguments: >
                  -Ttl 120

```

## Post deploy script example

```yaml Post deploy script example without optional Ttl parameter

postDeployScriptsList:
  - displayName: Resolve Private Endpoint IP for $(keyvaultName)
  scriptPath: 'Get-ResourcePrivateEndPointsDnsRecordsAsJson.ps1@PipelineCommon'
  ScriptArguments: >
      -ResourceGroupName $(resourceGroupName)
      -ResourceName $(keyvaultName)
  - displayName: Set DNS record for $(keyvaultName)
  scriptPath: 'Set-PrivateDnsRecordSet.ps1@PipelineCommon'
  serviceConnectionVariableName: mstAzureResourceManagerConnection

```