<#
    .SYNOPSIS
        Set-PrivateDnsRecordSet
    .DESCRIPTION
        This script creates a record set in a Private DNS zone based on the privateEndpointDnsRecordsJson variable.
#>
Param(
    [Parameter(Mandatory = $false)]
    [int]$Ttl = 60
)

Function Get-RegionToResourceGroupMappingTable {
    $regionToResourceGroupMappingTableObject = $env:REGION_TO_DNS_RESOURCEGROUP_MAPPING_TABLE | ConvertFrom-Json

    foreach ($property in $regionToResourceGroupMappingTableObject.PSObject.Properties) {
        $regionToResourceGroupMappingTable[$property.Name] = $property.Value
    }

    return $regionToResourceGroupMappingTable
}

Function Get-PrivateDnsZoneMappingTable {
    $privateDnsZones = Get-AzPrivateDnsZone
    $uniquePrivateDnsZonesNames = $privateDnsZones.Name | Sort-Object -Unique

    foreach ($zoneName in $uniquePrivateDnsZonesNames) {
        if ($zoneName -eq 'privatelink.vaultcore.azure.net') {
            $domainPrivateDnsZoneMappingTable["vault.azure.net"] = "privatelink.vaultcore.azure.net"
        }
        else {
            $nameWithoutPrivatelink = $zoneName -replace "privatelink.", ''
            $domainPrivateDnsZoneMappingTable["$nameWithoutPrivatelink"] = "$zoneName"
        }
    }

    return $domainPrivateDnsZoneMappingTable
}

Function Get-RecordForPrivateDnsZone {
    Param(
        $Fqdn,
        $DomainPrivateDnsZoneMappingTable
    )

    $foundResourceDomain = $null
    foreach ($resourceDomain in $DomainPrivateDnsZoneMappingTable.Keys) {
        if ($Fqdn.EndsWith('scm.azurewebsites.net')) {
            $foundResourceDomain = 'scm.azurewebsites.net'
            break
        }

        if ($Fqdn.EndsWith($resourceDomain)) {
            $foundResourceDomain = $resourceDomain
            break
        }
    }

    if ($null -eq $foundResourceDomain) {
        throw "This $Fqdn resource domain is not supported"
    }

    $nameWithoutDomain = $Fqdn -replace ".$foundResourceDomain", ''
    $privateDnsZoneDomain = $DomainPrivateDnsZoneMappingTable[$foundResourceDomain]

    return @{ Name = $nameWithoutDomain; Domain = $privateDnsZoneDomain }
}

try {

    Write-Output ("Setting Private DNS record")
    Write-Output ("PrivateEndpointDnsRecordsJson > $($env:PRIVATEENDPOINTDNSRECORDSJSON)")

    $privateEndpointDnsRecordObject = $env:PRIVATEENDPOINTDNSRECORDSJSON | ConvertFrom-Json

    $regionToResourceGroupMappingTable = @{}
    $regionToResourceGroupMappingTable = Get-RegionToResourceGroupMappingTable

    $domainPrivateDnsZoneMappingTable = @{}
    $domainPrivateDnsZoneMappingTable = Get-PrivateDnsZoneMappingTable

    foreach ( $privateEndpointDnsRecord in $privateEndpointDnsRecordObject ) {
        $privateDnsRecord = Get-RecordForPrivateDnsZone -Fqdn $privateEndpointDnsRecord.Fqdn -DomainPrivateDnsZoneMappingTable $domainPrivateDnsZoneMappingTable
    
        foreach ($ipAddress in $privateEndpointDnsRecord.IpAddress) {
            Write-Output ("Setting record >")
            Write-Output ("ZoneName: $($privateDnsRecord.Domain)")
            Write-Output ("DnsResourceGroup: " + $regionToResourceGroupMappingTable[$privateEndpointDnsRecord.Region])
            Write-Output ("RecordSetName: $($privateDnsRecord.Name)")
            Write-Output ("IpAddress: " + $ipAddress)
            Write-Output ("RecordType: A")
            Write-Output ("Ttl: $Ttl")

            New-AzPrivateDnsRecordSet `
                -Name $privateDnsRecord.Name `
                -ZoneName $privateDnsRecord.Domain `
                -ResourceGroupName $regionToResourceGroupMappingTable[$privateEndpointDnsRecord.Region] `
                -Ttl $Ttl `
                -RecordType 'A' `
                -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -Ipv4Address $ipAddress) `
                -Overwrite
        }
    }

    # Delete PrivateDnsRecordsJson environment variable to prevent accidental re-use of the same environmet variable in subsequent
    # Set-PrivateDnsRecordSet tasks, if the Consumer forgets to call the Get-ResourcePrivateEndPointsDnsRecordsAsJson first.
    Remove-Item Env:\PRIVATEENDPOINTDNSRECORDSJSON
}
catch {
    Write-Output "Error creating new Private DNS record set for $name : $($_.Exception.ToString())"
    throw $_
}
