<#
    .SYNOPSIS
        Get-ResourcePrivateEndPointsDnsRecordsAsJson
    .DESCRIPTION
        This script will return IP addresses and their associated fqdn and region.
#>
Param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$ResourceName
)

try {
    Write-Output "Getting DNS record details for resource $ResourceName in resource-group $ResourceGroupName"

    $resourceProperties = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $ResourceName -ExpandProperties
    $privateEndpointConnections = $resourceProperties.properties.privateEndpointConnections

    $privateDnsRecordObject = @()

    foreach ($privateEndpointConnection in $privateEndpointConnections) {
        
        if (!$null -eq $privateEndpointConnection) {
            $privateEndpointResourceId = $privateEndpointConnection.properties.privateEndpoint.id
            $privateEndpointResourceIdArray = $privateEndpointResourceId.Split('/')
            $privateEndpointResourceGroup = $privateEndpointResourceIdArray[4]
            $privateEndpointName = $privateEndpointResourceIdArray[8]
            $privateEndpointProperties = Get-AzPrivateEndpoint -ResourceGroupName $privateEndpointResourceGroup -Name $privateEndpointName -ErrorAction 'SilentlyContinue'
            if($privateEndpointProperties){
                $privateEndpointLocation = $privateEndpointProperties.Location

                foreach ($config in $privateEndpointProperties.CustomDnsConfigs) {
                    $privateDnsRecordDetails = New-Object psobject
                    $privateDnsRecordDetails | Add-Member -MemberType NoteProperty "Region" -Value $privateEndpointLocation
                    $privateDnsRecordDetails | Add-Member -MemberType NoteProperty "Fqdn" -Value $config.Fqdn
                    $privateDnsRecordDetails | Add-Member -MemberType NoteProperty "IpAddress" -Value $config.IpAddresses
                    $privateDnsRecordObject += $privateDnsRecordDetails
                }
            }   
            else {
                $subscription = $privateEndpointResourceIdArray[2]
                Write-Warning "Error finding Private Endpoint $privateEndpointName in subscription $subscription in resource group $privateEndpointResourceGroup. This could be a shared private access endpoint"
            }
        }
    }

    $privateEndpointDnsRecordString = $privateDnsRecordObject | ConvertTo-Json -Compress
    
    Write-Output "privateEndpointDnsRecordString: $privateEndpointDnsRecordString"
    Write-Output "##vso[task.setvariable variable=PrivateEndpointDnsRecordsJson]$privateEndpointDnsRecordString"
}
catch {
    Write-Output "Error resolving Private Endpoint IP for $PrivateEndpointName in resource group $ResourceGroupName : $($_.Exception.ToString())"
    throw $_
}