    <#
    .SYNOPSIS
        Invoke a command and return the output.
    .DESCRIPTION
        Invoke a command and return the output.
    .PARAMETER Command
        The command to invoke.
    .PARAMETER IsSensitive
        If true, the command will be hidden.
    .PARAMETER IgnoreErrorCode
        If true, the command ignore the error.
    .PARAMETER ReturnExitCode
        If true, the command will return LASTEXITCODE.
    .PARAMETER NoOutput
        If true, the command will not output anything.
    #>

    function Invoke-CommandLine {
        param(
            [Parameter(Mandatory)]
            [string]$Command,
            [switch]$IsSensitive,
            [switch]$IgnoreErrorCode,
            [switch]$ReturnExitCode,
            [switch]$NoOutput
        )
    
        [string]$functionName = $MyInvocation.MyCommand
    
        if ($IsSensitive) {
            
        } 
        else {
            
        }
    
        [string]$errorMessage = ""
        [string]$warningMessage = ""
        [string]$outputMessage = ""
        [string]$informationMessage = ""
    
        $output = Invoke-Expression -Command $Command -ErrorVariable errorMessage -WarningVariable warningMessage -OutVariable outputMessage -InformationVariable informationMessage 
        [int]$errCode = $LASTEXITCODE
    
        
    
        if (-not [string]::IsNullOrWhiteSpace($outputMessage)) { 
            Write-Verbose $outputMessage 
        }
    
        if (-not [string]::IsNullOrWhiteSpace($informationMessage)) { 
            Write-Verbose $informationMessage 
        }
    
        if (-not [string]::IsNullOrWhiteSpace($warningMessage)) {
            Write-Warning $warningMessage 
        }
    
        if (-not [string]::IsNullOrWhiteSpace($errorMessage)) {
            Write-Verbose $errorMessage
            Write-Error $errorMessage
            throw "$errorMessage"
        }
    
        if ($errCode -ne 0 -and -not $IgnoreErrorCode) {
            throw "unexpected exit code $errCode"
        }
    
        if ($ReturnExitCode) {
            Write-Output $errCode
        }
        elseif (-not $NoOutput) {
            Write-Output $output
        }
        
    }
