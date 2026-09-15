[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$requiredVersion = [version]'5.9.0'
$available = @(
    Get-Module -ListAvailable -Name Pester |
        Where-Object Version -EQ $requiredVersion
)

if ($available.Count -lt 1) {
    throw "Pester $requiredVersion is required exactly and was not found. No module was installed automatically."
}

Import-Module Pester -RequiredVersion $requiredVersion -Force
$imported = Get-Module -Name Pester
if ($null -eq $imported -or [version]$imported.Version -ne $requiredVersion) {
    throw "Imported Pester version '$($imported.Version)' does not match required version '$requiredVersion'."
}
$configuration = New-PesterConfiguration
$configuration.Run.Path = Join-Path $PSScriptRoot 'PublicPublication.Tests.ps1'
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $configuration

if ($result.TotalCount -le 0) {
    throw 'Pester discovered or executed zero tests.'
}
if ($result.FailedCount -gt 0) {
    throw "Pester failed $($result.FailedCount) of $($result.TotalCount) tests."
}
