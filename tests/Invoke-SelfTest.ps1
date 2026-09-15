[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $repositoryRoot 'scripts\Validate-Publication.ps1'
$fixture = Join-Path $PSScriptRoot 'fixtures\valid'
$policy = Join-Path $repositoryRoot '.github\publication-path-policy.json'
$schemas = Join-Path $repositoryRoot 'schemas'
$pwsh = (Get-Process -Id $PID).Path
$testsRun = 0

function New-FixtureCopy {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) "publication-validator-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $path | Out-Null
    Copy-Item -Path (Join-Path $fixture '*') -Destination $path -Recurse -Force
    return $path
}

function Invoke-ValidatorCase {
    param(
        [string]$Name,
        [bool]$ShouldPass,
        [scriptblock]$Mutate
    )
    $script:testsRun++
    $path = New-FixtureCopy
    try {
        if ($Mutate) { & $Mutate $path }
        & $pwsh -NoLogo -NoProfile -File $validator `
            -RepositoryRoot $path `
            -ValidationMode Snapshot `
            -SchemaRoot $schemas `
            -PolicyPath $policy *> $null
        $passed = $LASTEXITCODE -eq 0
        if ($passed -ne $ShouldPass) {
            throw "Case '$Name' expected pass=$ShouldPass but validator exit code was $LASTEXITCODE."
        }
        Write-Host "PASS: $Name"
    }
    finally {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

Invoke-ValidatorCase -Name 'valid deterministic bundle' -ShouldPass $true

Invoke-ValidatorCase -Name 'forged hash' -ShouldPass $false -Mutate {
    param($path)
    $manifestPath = Join-Path $path 'generated-manifest.json'
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $manifest.files[0].sha256 = '0' * 64
    $manifest | ConvertTo-Json -Depth 20 | Set-Content $manifestPath -Encoding utf8NoBOM
}

Invoke-ValidatorCase -Name 'unlisted generated file' -ShouldPass $false -Mutate {
    param($path)
    $scriptPath = Join-Path $path 'templates\entra\conditional-access\synthetic-policy-fixture\scripts'
    New-Item -ItemType Directory -Path $scriptPath | Out-Null
    Set-Content -LiteralPath (Join-Path $scriptPath 'unlisted.ps1') -Value "'fixture'" -Encoding utf8NoBOM
}

Invoke-ValidatorCase -Name 'path traversal' -ShouldPass $false -Mutate {
    param($path)
    $manifestPath = Join-Path $path 'generated-manifest.json'
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $manifest.files[0].path = '../catalog.json'
    $manifest | ConvertTo-Json -Depth 20 | Set-Content $manifestPath -Encoding utf8NoBOM
}

Invoke-ValidatorCase -Name 'case collision' -ShouldPass $false -Mutate {
    param($path)
    $manifestPath = Join-Path $path 'generated-manifest.json'
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $collision = $manifest.files[1].PSObject.Copy()
    $collision.path = $collision.path.ToUpperInvariant()
    $manifest.files = @($manifest.files) + $collision
    $manifest | ConvertTo-Json -Depth 20 | Set-Content $manifestPath -Encoding utf8NoBOM
}

Invoke-ValidatorCase -Name 'unknown metadata field' -ShouldPass $false -Mutate {
    param($path)
    $metadataPath = Join-Path $path 'templates\entra\conditional-access\synthetic-policy-fixture\metadata.json'
    $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
    $metadata | Add-Member -NotePropertyName unexpectedInternalField -NotePropertyValue 'must fail'
    $metadata | ConvertTo-Json -Depth 20 | Set-Content $metadataPath -Encoding utf8NoBOM
}

Invoke-ValidatorCase -Name 'partial bundle cannot remove catalog entry' -ShouldPass $false -Mutate {
    param($path)
    $catalogPath = Join-Path $path 'catalog.json'
    $catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
    $catalog.artifacts = @()
    $catalog | ConvertTo-Json -Depth 20 | Set-Content $catalogPath -Encoding utf8NoBOM
}

if ($testsRun -le 0) {
    throw 'Self-test executed zero cases.'
}
Write-Host "Self-test passed: $testsRun cases."
