<#
 # SecuritySuite provider uses EXO Admin API calls directly.
#>

$ProviderPath = '../../../../../Modules/Providers'
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "$($ProviderPath)/ExportSecuritySuiteProvider.psm1") -Function Export-SecuritySuiteProvider -Force

InModuleScope -ModuleName ExportSecuritySuiteProvider {
    Describe -Tag 'ExportSecuritySuiteProvider' -Name 'Export-SecuritySuiteProvider' -ForEach @(
        'commercial',
        'gcc',
        'gcchigh',
        'dod'
    ) {
        BeforeAll {
            class MockCommandTracker {
                [string[]]$SuccessfulCommands = @()
                [string[]]$UnSuccessfulCommands = @()

                [System.Object[]] TryCommand([string]$Command, [hashtable]$CommandArgs) {
                    # Only Graph-based commands go through TryCommand in the REST provider.
                    # EXO commands use Invoke-EXORestMethod instead.
                    try {
                        switch ($Command) {
                            "Get-MgBetaSubscribedSku" {
                                $this.SuccessfulCommands += $Command
                                return [pscustomobject]@{
                                    ServicePlans = @(
                                        [pscustomobject]@{
                                            ServicePlanName    = "M365_ADVANCED_AUDITING"
                                            ServicePlanId      = "2f442157-a11c-46b9-ae5b-6e39ff4e5849"
                                            ProvisioningStatus = "Success"
                                        }
                                    )
                                }
                            }
                            default {
                                throw "ERROR you forgot to create a mock method for this cmdlet: $($Command)"
                            }
                        }
                        $Result = @()
                        $this.SuccessfulCommands += $Command
                        return $Result
                    }
                    catch {
                        Write-Warning "Error running $($Command). $($_)"
                        $this.UnSuccessfulCommands += $Command
                        $Result = @()
                        return $Result
                    }
                }

                [System.Object[]] TryCommand([string]$Command) {
                    return $this.TryCommand($Command, @{})
                }

                [void] AddSuccessfulCommand([string]$Command) {
                    $this.SuccessfulCommands += $Command
                }

                [void] AddUnSuccessfulCommand([string]$Command) {
                    $this.UnSuccessfulCommands += $Command
                }

                [string[]] GetUnSuccessfulCommands() {
                    return $this.UnSuccessfulCommands
                }

                [string[]] GetSuccessfulCommands() {
                    return $this.SuccessfulCommands
                }
            }

            function Get-CommandTracker {}
            function Invoke-EXORestMethod {}
            function Trace-ScubaFunction {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
                param($FunctionName, $Parameters, [scriptblock]$ScriptBlock, $LogReturnValue, $LogErrors)
                & $ScriptBlock
            }

            Mock -ModuleName ExportSecuritySuiteProvider Import-Module {}
            Mock -ModuleName ExportSecuritySuiteProvider Get-CommandTracker {
                return [MockCommandTracker]::New()
            }
            Mock -ModuleName ExportSecuritySuiteProvider Invoke-EXORestMethod {
                switch ($CmdletName) {
                    'Get-DlpComplianceRule' {
                        [pscustomobject]@{
                            Name = $CmdletName
                            ContentContainsSensitiveInformation = @()
                        }
                    }
                    default {
                        [pscustomobject]@{ Name = $CmdletName }
                    }
                }
            }

            function Test-SCuBAValidProviderJson {
                param (
                    [string]
                    $Json
                )
                $Json = $Json.TrimEnd(',')
                $Json = "{$($Json)}"
                $ValidJson = $true
                try {
                    ConvertFrom-Json $Json -ErrorAction Stop | Out-Null
                }
                catch {
                    $ValidJson = $false
                }
                $ValidJson
            }
        }

        It "When called with -M365Environment '<_>', returns valid JSON" {
            $Json = Export-SecuritySuiteProvider -M365Environment $_ -AccessToken 'token' -ApiEndpoint 'https://example.test/adminapi/beta/tenant/InvokeCommand' -ComplianceAccessToken 'comptoken' -ComplianceApiEndpoint 'https://example.test/compliance/adminapi/beta/tenant/InvokeCommand'
            $ValidJson = Test-SCuBAValidProviderJson -Json $Json | Select-Object -Last 1
            $ValidJson | Should -Be $true
        }

        It "When called with -M365Environment '<_>', records expected command names" {
            $Json = Export-SecuritySuiteProvider -M365Environment $_ -AccessToken 'token' -ApiEndpoint 'https://example.test/adminapi/beta/tenant/InvokeCommand' -ComplianceAccessToken 'comptoken' -ComplianceApiEndpoint 'https://example.test/compliance/adminapi/beta/tenant/InvokeCommand'
            $Parsed = ('{' + $Json.TrimEnd(',') + '}') | ConvertFrom-Json
            $Parsed.securitysuite_successful_commands | Should -Contain 'Get-AdminAuditLogConfig'
            $Parsed.securitysuite_successful_commands | Should -Contain 'Get-EOPProtectionPolicyRule'
            $Parsed.securitysuite_successful_commands | Should -Contain 'Get-AntiPhishPolicy'
        }
    }
}

AfterAll {
    Remove-Module ExportSecuritySuiteProvider -Force -ErrorAction SilentlyContinue
    Remove-Module CommandTracker -Force -ErrorAction SilentlyContinue
}
