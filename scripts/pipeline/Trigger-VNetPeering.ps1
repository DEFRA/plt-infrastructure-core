<#
.SYNOPSIS
Triggers ADO pipeline to link the VNet to hub (central) networks.

.DESCRIPTION
Triggers a pipeline in CCoE-Infrastructure ADO project to link the DNS zone to central networks.
Self-contained: no dependency on ADP or other repos.

.PARAMETER VirtualNetworkName
Mandatory. Virtual network name to link to hub.

.PARAMETER SubscriptionName
Mandatory. Subscription name where the VNet resides.

.PARAMETER TenantId
Mandatory. Tenant ID.

.PARAMETER PeerToSec
Optional. Peer to sec vnet. Defaults to false.

.EXAMPLE
.\Trigger-VNetPeering.ps1 -VirtualNetworkName "my-vnet" -SubscriptionName "my-sub" -TenantId "tenant-guid" -PeerToSec $false
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$VirtualNetworkName,
    [Parameter(Mandatory)]
    [string]$SubscriptionName,
    [Parameter(Mandatory)]
    [string]$TenantId,
    [Parameter()]
    [bool]$PeerToSec = $false
)

Set-StrictMode -Version 3.0

[string]$functionName = $MyInvocation.MyCommand
[datetime]$startTime = [datetime]::UtcNow

[int]$exitCode = -1
[bool]$setHostExitCode = (Test-Path -Path ENV:TF_BUILD) -and ($ENV:TF_BUILD -eq "true")
[bool]$enableDebug = (Test-Path -Path ENV:SYSTEM_DEBUG) -and ($ENV:SYSTEM_DEBUG -eq "true")

Set-Variable -Name ErrorActionPreference -Value Stop -Scope global
Set-Variable -Name InformationPreference -Value Continue -Scope global

if ($enableDebug) {
    Set-Variable -Name VerbosePreference -Value Continue -Scope global
    Set-Variable -Name DebugPreference -Value Continue -Scope global
}

Write-Host "${functionName} started at $($startTime.ToString('u'))"
Write-Debug "${functionName}:VirtualNetworkName=$VirtualNetworkName"
Write-Debug "${functionName}:SubscriptionName=$SubscriptionName"
Write-Debug "${functionName}:TenantId=$TenantId"
Write-Debug "${functionName}:PeerToSec=$PeerToSec"

function Get-AdoHeaders {
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $env:SYSTEM_ACCESSTOKEN"
    }
    return $headers
}

try {
    if ([string]::IsNullOrWhiteSpace($env:SYSTEM_ACCESSTOKEN)) {
        throw "SYSTEM_ACCESSTOKEN is not set. Ensure the step has useSystemAccessToken: true."
    }

    [object]$runPipelineRequestBody = @{
        templateParameters = @{
            VirtualNetworkName = $VirtualNetworkName
            Subscription       = $SubscriptionName
            Tenant             = $TenantId
            PeerToSec          = $PeerToSec.ToString()
        }
    } | ConvertTo-Json

    $organisationUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI.TrimEnd('/') + '/'
    $projectName = "CCoE-Infrastructure"
    $buildDefinitionId = 1851
    $uriPostRunPipeline = "${organisationUri}${projectName}/_apis/pipelines/${buildDefinitionId}/runs?api-version=7.0"

    Write-Host "Triggering pipeline: $projectName (definition $buildDefinitionId)"
    $headers = Get-AdoHeaders
    $pipelineRun = Invoke-RestMethod -Uri $uriPostRunPipeline -Method Post -Headers $headers -Body $runPipelineRequestBody

    Write-Host "Pipeline run id: $($pipelineRun.id), state: $($pipelineRun.state)"

    $pipelineStateCheckMaxWaitTimeOutInSec = 600
    $totalSleepInSec = 0
    do {
        Start-Sleep -Seconds 60
        $totalSleepInSec += 60
        $getPipelineRunStateUri = "${organisationUri}${projectName}/_apis/pipelines/${buildDefinitionId}/runs/$($pipelineRun.id)?api-version=7.0"
        $pipelineRunDetails = Invoke-RestMethod -Uri $getPipelineRunStateUri -Method Get -Headers $headers
        $currentState = $pipelineRunDetails.state
        Write-Host "Current state of run $($pipelineRun.id): $currentState"
        if ($currentState -ne "inProgress") {
            $result = $pipelineRunDetails.result
            if ($result -eq "succeeded") {
                Write-Host "Pipeline completed successfully."
                $exitCode = 0
            } else {
                Write-Host "##vso[task.logissue type=error]Pipeline run $($pipelineRunDetails.pipeline.name) (id $($pipelineRunDetails.id)) failed with result: $result"
                $exitCode = 1
            }
            break
        }
        if ($totalSleepInSec -ge $pipelineStateCheckMaxWaitTimeOutInSec) {
            Write-Host "##vso[task.logissue type=error]Pipeline run timed out after $pipelineStateCheckMaxWaitTimeOutInSec seconds."
            $exitCode = 1
            break
        }
    } while ($true)
}
catch {
    $exitCode = -2
    Write-Error $_.Exception.ToString()
    throw $_.Exception
}
finally {
    [DateTime]$endTime = [DateTime]::UtcNow
    [TimeSpan]$duration = $endTime.Subtract($startTime)
    Write-Host "${functionName} finished at $($endTime.ToString('u')) (duration $($duration.ToString('g'))) with exit code $exitCode"
    if ($setHostExitCode) {
        $host.SetShouldExit($exitCode)
    }
    exit $exitCode
}
