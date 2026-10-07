# Detect-McAfee-PlatformScript.ps1
# Purpose: Report whether McAfee|Trellix|Endpoint Security|ENS|Agent)'# Purpose: Report whether McAfee / Trellix components are present on the device

# 1) Installed applications (common uninstall registry locations)
$uninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$installedApps = foreach ($path in $uninstallPaths) {
    Get-ItemProperty -Path $path | Where-Object {
        ($_.DisplayName -match $productPattern) -or
        ($_.Publisher -match $vendorPattern)
    } | Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation, PSPath
}

$installedApps = $installedApps | Sort-Object DisplayName -Unique

# 2) Services
$services = Get-Service | Where-Object {
    $_.Name -match $productPattern -or $_.DisplayName -match $productPattern
} | Select-Object Name, DisplayName, Status

# 3) Known folders
$knownPaths = @(
    'C:\Program Files\McAfee',
    'C:\Program Files (x86)\McAfee',
    'C:\Program Files\Trellix',
    'C:\Program Files (x86)\Trellix',
    'C:\ProgramData\McAfee',
    'C:\ProgramData\Trellix'
)

$existingPaths = $knownPaths | Where-Object { Test-Path $_ }

# 4) Agent executable hints
$agentFiles = @(
    'C:\Program Files\McAfee\Agent\x86\FrmInst.exe',
    'C:\Program Files (x86)\McAfee\Agent\x86\FrmInst.exe',
    'C:\Program Files\Trellix\Agent\x86\FrmInst.exe',
    'C:\Program Files (x86)\Trellix\Agent\x86\FrmInst.exe'
) | Where-Object { Test-Path $_ }

# 5) Build result
$detected = ($installedApps.Count -gt 0) -or ($services.Count -gt 0) -or ($existingPaths.Count -gt 0) -or ($agentFiles.Count -gt 0)

$result = [PSCustomObject]@{
    ComputerName     = $env:COMPUTERNAME
    McAfeeDetected   = $detected
    InstalledApps    = @($installedApps | ForEach-Object {
        if ($_.DisplayVersion) {
            "$($_.DisplayName) ($($_.DisplayVersion))"
        } else {
            "$($_.DisplayName)"
        }
    })
    Services         = @($services | ForEach-Object { "$($_.DisplayName) [$($_.Status)]" })
    Paths            = @($existingPaths)
    AgentFiles       = @($agentFiles)
    ScanTimeUtc      = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
}

# Output compact JSON so it is easy to read in Intune results / export
$result | ConvertTo-Json -Compress -Depth 4

# Platform script should succeed if detection ran successfully
exit 0
# Recommended Intune settings:
# - Run this script using the logged on credentials: No
# - Run script in 64-bit PowerShell host: Yes

$ErrorActionPreference = 'SilentlyContinue'

$vendorPattern = '(?i)(McAfee|Trellix)'
