<#
    .SYNOPSIS
       Powershell for additional App Reg functions.
    .DESCRIPTION
        This script contains rbac functions for app reg 
#>

Function Get-AppRegRenewalLinkedAppServicePrincipalId {
    Param(
        [Parameter(Mandatory = $true)]
        [String]$KeyVaultTenantId
    )

    $defraCloudDevTenantId = $env:TENANT_DEFRACLOUDDEV_ID
    $o365DefraDevTenantId = $env:TENANT_DEFRADEV_ID 
    $defraCloudPreTenantId = $env:TENANT_DEFRACLOUDPRE_ID
    $defraCloudTenantId = $env:TENANT_DEFRACLOUD_ID
    $defraTenantId = $env:TENANT_DEFRA_ID

    $appRegTenantId = (Get-AzContext).Tenant.Id

    [string]$linkedAppRegRenewalAppServicePrincipalId = $null
    switch ($KeyVaultTenantId) {
        $defraCloudDevTenantId {
            if ($appRegTenantId -eq $defraTenantId) {
                $linkedAppRegRenewalAppServicePrincipalId = $env:LINKEDSECRETRENEWALSPOBJECT_DEFRACLOUDDEV_TO_DEFRA_DEV_ID
            }
            elseif ($appRegTenantId -eq $o365DefraDevTenantId) {
                $linkedAppRegRenewalAppServicePrincipalId = $env:LINKEDSECRETRENEWALSPOBJECT_DEFRACLOUDDEV_TO_O365DEFRADEV_ID
            }
            else {
                throw "Tenant ID $appRegTenantId does not match defraTenantId $defraTenantId or o365DefraDevTenantId $o365DefraDevTenantId"
            }
            
            break
        }
        $o365DefraDevTenantId {
            if ($appRegTenantId -eq $defraCloudDevTenantId) {
                $linkedAppRegRenewalAppServicePrincipalId = $env:LINKEDSECRETRENEWALSPOBJECT_O365DEFRADEV_DEFRACLOUDDEV_ID
            }
            elseif ($appRegTenantId -eq $defraTenantId) {
                $linkedAppRegRenewalAppServicePrincipalId = $env:LINKEDSECRETRENEWALSPOBJECT_O365DEFRADEV_DEFRA_DEV_ID
            }
            else {
                throw "Tenant ID $appRegTenantId does not match defraTenantId $defraTenantId or o365DefraDevTenantId $o365DefraDevTenantId"
            }
           
            break
        }
        $defraCloudPreTenantId {
            $linkedAppRegRenewalAppServicePrincipalId = $env:LINKEDSECRETRENEWALSPOBJECT_DEFRACLOUDPRE_TO_DEFRA_PRE_ID
            break
        }
        $defraCloudTenantId {
            $linkedAppRegRenewalAppServicePrincipalId = $env:LINKEDSECRETRENEWALSPOBJECT_DEFRACLOUD_TO_DEFRA_PRD_ID
            break
        }
        $defraTenantId {
            switch ($appRegTenantId) {
                $defraCloudDevTenantId {
                    $linkedAppRegRenewalAppServicePrincipalId = $env:LINKEDSECRETRENEWALSPOBJECT_DEFRA_DEV_TO_DEFRACLOUDDEV_ID
                    break
                }
                $o365DefraDevTenantId {
                    $linkedAppRegRenewalAppServicePrincipalId = $env:LINKEDSECRETRENEWALSPOBJECT_DEFRA_DEV_TO_O365DEFRADEV_ID
                    break
                }
                $defraCloudPreTenantId {
                    $linkedAppRegRenewalAppServicePrincipalId = $env:LINKEDSECRETRENEWALSPOBJECT_DEFRA_PRE_TO_DEFRACLOUDPRE_ID
                    break
                }
                $defraCloudTenantId {
                    $linkedAppRegRenewalAppServicePrincipalId = $env:LINKEDSECRETRENEWALSPOBJECT_DEFRA_PRD_TO_DEFRACLOUD_ID
                    break
                }
            }
        }
    }

    return $linkedAppRegRenewalAppServicePrincipalId
}

Function Get-AppRegSecretRenewalInfo {
    Param(
        [Parameter(Mandatory = $True)]
        [Object]$app
    )
    
    $notes = [string]::Empty
    if ($app.notes) {
        $notes += $app.notes
    }

    $renewalNotificationEmailAddress = [string]::Empty
    if ($app.renewalNotificationEmailAddress) {
        $renewalNotificationEmailAddress += $app.renewalNotificationEmailAddress
    }

    $appObjectForInternalNote = [PSCustomObject]@{
        secretAutoRenewalEnabled        = $app.secretAutoRenewalEnabled
        renewalNotificationEmailAddress = $renewalNotificationEmailAddress
        notes                           = $notes
    }

    if ($app.keyVault) {
        $keyVault = [PSCustomObject]@{
            name = $app.keyVault.name
        }

        if ($app.keyvault.tenant) {
            $tenant = [PSCustomObject]@{
                id = $app.keyVault.tenant.id
            }
            $keyVault | Add-Member noteproperty "tenant" $tenant -force
        }

        $secrets = @()
        if ($app.keyvault.secrets) {
            $secrets = $app.keyvault | Select-Object -ExpandProperty secrets | Where-Object { $_.type -eq "ClientSecret" }
            $secrets = $secrets | Select-Object * -ExcludeProperty type
        }
        $keyVault | Add-Member noteproperty "secrets" $secrets -force
        $appObjectForInternalNote | Add-Member noteproperty "keyVault" $keyVault -force
    }

    return $appObjectForInternalNote
}

Function ConvertTo-AppRegNotesJson {
    Param(
        [Parameter(Mandatory = $True)]
        [Object]$appRegSecretRenewalInfo
    )
    
    $appRegSecretRenewalInfoJson = $appRegSecretRenewalInfo | ConvertTo-Json -Depth 100 -Compress

    $appRegSecretRenewalInfoJsonLength = $appRegSecretRenewalInfoJson.Length
    $numberOfCharactersAllowedForInternalNote = 1024

    if ($appRegSecretRenewalInfoJsonLength -gt $numberOfCharactersAllowedForInternalNote) {
        $exceededCharacterLength = $appRegSecretRenewalInfoJsonLength - $numberOfCharactersAllowedForInternalNote
        $notesCharacterLength = $appRegSecretRenewalInfo.notes.Length
        $additonalLengthForPeriodsOnNotes = 3
        $newNotesCharacterLength = $notesCharacterLength - ($exceededCharacterLength + $additonalLengthForPeriodsOnNotes)
        $trimmedNotes = $appRegSecretRenewalInfo.notes.substring(0, $newNotesCharacterLength)   
        $appRegSecretRenewalInfo.notes = $trimmedNotes += "..."
        $appRegSecretRenewalInfoJson = $appRegSecretRenewalInfo | ConvertTo-Json -Depth 100 -Compress 
    }

    return $appRegSecretRenewalInfoJson
}

Function Get-SecretRenewalNotes {
    Param(
        [Parameter(Mandatory = $True)]
        [Object]$app
    )

    $appRegSecretRenewalInfo = Get-AppRegSecretRenewalInfo -App $app
    $appRegJsonForInternalNote = ConvertTo-AppRegNotesJson $appRegSecretRenewalInfo

    return $appRegJsonForInternalNote
}

Function Get-SecureStringAsPlainText {
    param (
        [Parameter(Mandatory = $True)]
        [SecureString]$SecureString
    )
    
    $secureStringToBinaryString = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    $secureStringAsPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($secureStringToBinaryString)

    return $secureStringAsPlainText
}

Function Get-DefaultHeadersWithAccessToken {
    param(
        [Parameter(Mandatory = $True)]$AzureTokenDomainName,
        [Parameter(Mandatory = $False)]$DefaultProfile
    )

    # Graph calls use the same entra SP client-secret as Create-AADGroups when provided.
    # ARM/Key Vault still uses the Azure PowerShell service connection context.
    $token = $null
    if ($AzureTokenDomainName -eq 'graph.microsoft.com' -and -not [string]::IsNullOrWhiteSpace($env:PLAT_GRAPH_ACCESS_TOKEN)) {
        $token = $env:PLAT_GRAPH_ACCESS_TOKEN
    }
    else {
        $resourceUrl = "https://$AzureTokenDomainName"
        try {
            $tokenResponse = Get-AzAccessToken -ResourceUrl $resourceUrl -DefaultProfile $DefaultProfile -ErrorAction Stop
        }
        catch {
            $tokenResponse = Get-AzAccessToken -Resource $resourceUrl -DefaultProfile $DefaultProfile
        }
        $token = $tokenResponse.Token
        if ($token -is [SecureString]) {
            $token = Get-SecureStringAsPlainText -SecureString $token
        }
    }

    $accessTokenHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $accessTokenHeaders.Add("Content-Type", "application/json")
    $accessTokenHeaders.Add("Authorization", "Bearer $token")

    return $accessTokenHeaders
}

Function New-RoleAssignment {
    Param(
        [Parameter(Mandatory = $true)]
        [Object]$ArmApiAccessTokenHeaders,
        [Parameter(Mandatory = $true)]
        [String]$ResourceId,
        [Parameter(Mandatory = $true)]
        [String]$RoleDefinitionId,
        [Parameter(Mandatory = $true)]
        [String]$PrincipalId
    )

    $uniqueRoleAssignmentIdentifier = (New-Guid).Guid

    $newRoleAssignmentUri = "https://management.azure.com/$($ResourceId)/providers/Microsoft.Authorization/roleAssignments/$($uniqueRoleAssignmentIdentifier)?api-version=2020-08-01-preview"

    $requestBodyForNewRoleAssignment = @{
        properties = @{
            roleDefinitionId = $RoleDefinitionId
            principalId      = $PrincipalId
            principalType    = "ServicePrincipal"
        }
    } | ConvertTo-Json

    $newRoleAssignmentParams = @{
        Headers     = $ArmApiAccessTokenHeaders
        Uri         = $newRoleAssignmentUri
        Method      = "PUT"
        Body        = $requestBodyForNewRoleAssignment
        ContentType = 'application/json'
    }
    Invoke-RestMethod @newRoleAssignmentParams
}

Function Get-RoleAssignment {
    Param(
        [Parameter(Mandatory = $true)]
        [Object]$ArmApiAccessTokenHeaders,
        [Parameter(Mandatory = $true)]
        [String]$ResourceId,
        [Parameter(Mandatory = $true)]
        [String]$PrincipalId
    )

    $uri = "https://management.azure.com/$ResourceId/providers/Microsoft.Authorization/roleAssignments?`$filter=principalId+eq+'$PrincipalId'&api-version=2020-08-01-preview"            
    $appRegRenewalAppServicePrincipalRoleAssignments = Invoke-RestMethod -Method 'Get' -Headers $ArmApiAccessTokenHeaders -Uri $uri
    
    return $appRegRenewalAppServicePrincipalRoleAssignments
}

Function Grant-SecretRenewalAppAccessToKeyVault {
    Param(
        [Parameter(Mandatory = $true)]
        [Object]$app,
        [Parameter(Mandatory = $True)]
        [Object]$defaultProfile,
        [Parameter(Mandatory = $True)]
        [Object]$appRegRenewalAppServicePrincipalId
    )

    if (-not $app.KeyVault.name) {
        throw "Cannot find the KeyVault resource named $($app.KeyVault.name) in manifest"
    }

    $keyVaultOptionalResourceGroup = @{}
    if (-not [string]::IsNullOrWhiteSpace($app.KeyVault.resourceGroup)) {
        $keyVaultOptionalResourceGroup.Add('ResourceGroupName', $app.KeyVault.resourceGroup)
    }

    $ArmApiAccessTokenHeaders = Get-DefaultHeadersWithAccessToken -AzureTokenDomainName 'management.azure.com' -DefaultProfile $defaultProfile

    if ($app.keyvault.tenant.SubscriptionName -or [string]::IsNullOrWhiteSpace($($app.KeyVault.SubscriptionName))) {
        $consumerKeyVault = Get-AzKeyVault -Name $app.KeyVault.name @keyVaultOptionalResourceGroup -DefaultProfile $defaultProfile
    } else {
        $subscriptionId = (Get-AzSubscription -SubscriptionName $app.KeyVault.SubscriptionName).Id
        Write-Output "subscriptionId: $subscriptionId"
        $consumerKeyVault = Get-AzKeyVault -Name $app.KeyVault.name @keyVaultOptionalResourceGroup -SubscriptionId $subscriptionId
    }

    if (-not $consumerKeyVault) {
        throw "Cannot find the KeyVault resource $($app.KeyVault.name)"
    }

    if ([string]::IsNullOrWhiteSpace($appRegRenewalAppServicePrincipalId)) {
        Write-Warning "App-Reg Secret Renewal is not supported for the current service connection context (tenant, subscription)"
    }
    else {
        if ($consumerKeyVault.EnableRbacAuthorization) {
            foreach ($secret in $app.keyVault.secrets) {

                if ($secret.type -eq 'ClientSecret') {

                    $appRegRenewalAppServicePrincipalRoleAssignmentsParams = @{
                        ArmApiAccessTokenHeaders = $ArmApiAccessTokenHeaders
                        ResourceId               = "$($consumerKeyVault.ResourceId)/secrets/$($secret.key)"
                        PrincipalId              = $appRegRenewalAppServicePrincipalId
                    }
                    $roleAssigmentsForAppRegRenewalApp = Get-RoleAssignment @appRegRenewalAppServicePrincipalRoleAssignmentsParams
            
                    $keyVaultSecretOfficerRoleDefinitionGuid = (Get-AzRoleDefinition -Name 'Key Vault Secrets Officer').Id
                
                    $keyVaultSecretOfficerRoleDefinitionResourceId = "/providers/Microsoft.Authorization/roleDefinitions/$($keyVaultSecretOfficerRoleDefinitionGuid)"
                    if (-not($roleAssigmentsForAppRegRenewalApp.value.properties.roleDefinitionId -match "$keyVaultSecretOfficerRoleDefinitionResourceId$")) {

                        Write-Output "Assigning Key vault Secrets Officer role to App Reg Secret Renewal App"

                        $newRoleAssignmentParams = @{
                            ArmApiAccessTokenHeaders = $ArmApiAccessTokenHeaders
                            ResourceId               = "$($consumerKeyVault.ResourceId)/secrets/$($secret.key)"
                            RoleDefinitionId         = $keyVaultSecretOfficerRoleDefinitionResourceId
                            PrincipalId              = $appRegRenewalAppServicePrincipalId
                        }

                        New-RoleAssignment @newRoleAssignmentParams

                        Write-Output "Key Vault Secrets Officer role has been assigned to App Reg Secret Renewal App"
                
                    }
                    else {
                        Write-Output "Key Vault Secrets Officer role already exists for App Reg Secret Renewal App"
                    }
                }
            }
        }
        else {
            Write-Output "Adding Vault access policy for Secrets to App Reg Secret Renewal App"
            if ($app.keyvault.tenant.SubscriptionName -or [string]::IsNullOrWhiteSpace($($app.KeyVault.SubscriptionName))) {
                Set-AzKeyVaultAccessPolicy -VaultName $app.KeyVault.name @keyVaultOptionalResourceGroup -ObjectId $appRegRenewalAppServicePrincipalId -PermissionsToSecrets set -BypassObjectIdValidation -DefaultProfile $defaultProfile
            } else {
                Set-AzKeyVaultAccessPolicy -VaultName $app.KeyVault.name @keyVaultOptionalResourceGroup -ObjectId $appRegRenewalAppServicePrincipalId -PermissionsToSecrets set -BypassObjectIdValidation -SubscriptionId $subscriptionId
            }
        }
    } 
}