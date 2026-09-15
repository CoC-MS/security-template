[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$requiredVersion = [version]'5.7.1'
$available = Get-Module -ListAvailable -Name Pester |
    Where-Object Version -EQ $requiredVersion |
    Select-Object -First 1

if ($null -eq $available) {
    throw "Pester $requiredVersion is required exactly and was not found. No module was installed automatically."
}

Import-Module $available.Path -Force
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
