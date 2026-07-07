<#
.SYNOPSIS
    Checks ScubaGear dependencies and optionally checks for version updates.

.DESCRIPTION
    Runs Test-ScubaGearVersion to check dependency status and ScubaGear version.
    The PSGallery version check (internet call) is skipped when the environment
    variable SCUBAGEAR_SKIP_VERSION_CHECK is set, for faster module import.
    The local dependency check always runs regardless of the environment variable.

.EXAMPLE
    .\Dependencies.ps1

.NOTES
    This script is automatically invoked during module import via ScriptsToProcess.
    To skip the PSGallery version check: $env:SCUBAGEAR_SKIP_VERSION_CHECK = $true
#>

[CmdletBinding()]
param()

try {
    $SupportModulesPath = Join-Path -Path $PSScriptRoot -ChildPath "Modules/Support/Support.psm1"
    Import-Module -Name $SupportModulesPath -ErrorAction Stop

    # Run version and dependency check
    # Skip the PSGallery internet call if the env var is set
    if (-not [string]::IsNullOrWhiteSpace($env:SCUBAGEAR_SKIP_VERSION_CHECK)) {
        $null = Test-ScubaGearVersion -SkipVersionCheck
    }
    else {
        $null = Test-ScubaGearVersion
    }
}
catch {
    Write-Error "An error occurred checking version status: $($_.Exception.Message)"
    throw
}