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
        [scriptblock]$Mutate,
        [string]$ExpectedMessage
    )
    $script:testsRun++
    $path = New-FixtureCopy
    try {
        if ($Mutate) { & $Mutate $path }
        $output = & $pwsh -NoLogo -NoProfile -File $validator `
            -RepositoryRoot $path `
            -ValidationMode Snapshot `
            -SchemaRoot $schemas `
            -PolicyPath $policy 2>&1 | Out-String
        $passed = $LASTEXITCODE -eq 0
        if ($passed -ne $ShouldPass) {
            throw "Case '$Name' expected pass=$ShouldPass but validator exit code was $LASTEXITCODE. Output: $output"
        }
        if ($ExpectedMessage -and $output -notmatch [regex]::Escape($ExpectedMessage)) {
            throw "Case '$Name' did not report '$ExpectedMessage'. Output: $output"
        }
        Write-Host "PASS: $Name"
    }
    finally {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

function Write-Utf8Lf {
    param(
        [string]$Path,
        [string]$Content
    )
    $utf8 = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($Path, $Content.Replace("`r`n", "`n").Replace("`r", "`n"), $utf8)
}

function New-PullRequestRepository {
    param([scriptblock]$PrepareBase)

    $path = New-FixtureCopy
    Write-Utf8Lf (Join-Path $path 'governance-source.md') "Synthetic governance source.`n"
    if ($PrepareBase) { & $PrepareBase $path }
    & git -C $path init --quiet
    & git -C $path config core.autocrlf false
    & git -C $path config user.email 'validator@example.invalid'
    & git -C $path config user.name 'Publication Validator Test'
    & git -C $path add --all
    & git -C $path commit --quiet -m 'base'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to create temporary base commit.' }
    return [ordered]@{
        Path = $path
        Base = (& git -C $path rev-parse HEAD)
    }
}

function Invoke-PullRequestCase {
    param(
        [string]$Name,
        [scriptblock]$Mutate,
        [string]$ExpectedMessage,
        [bool]$ShouldPass = $false,
        [scriptblock]$PrepareBase,
        [string]$Title = '[Generated publication] Synthetic validation',
        [string]$Body = "<!-- generated-publication -->`n## Publication summary`nSynthetic test`n## Artifacts`nSynthetic test`n## Removals`nNone`n## Validation`nSynthetic test"
    )
    $script:testsRun++
    $repository = New-PullRequestRepository -PrepareBase $PrepareBase
    $eventPath = Join-Path ([IO.Path]::GetTempPath()) "publication-event-$([guid]::NewGuid().ToString('N')).json"
    try {
        if ($Mutate) {
            & $Mutate $repository.Path
            & git -C $repository.Path add --all
            & git -C $repository.Path commit --quiet -m 'candidate'
            if ($LASTEXITCODE -ne 0) { throw "Unable to commit mutation for '$Name'." }
        }
        $event = [ordered]@{
            pull_request = [ordered]@{
                title = $Title
                body = $Body
                head = [ordered]@{ ref = 'publication/synthetic-validation' }
            }
            sender = [ordered]@{ login = 'publisher[bot]' }
        }
        Write-Utf8Lf $eventPath (($event | ConvertTo-Json -Depth 10) + "`n")
        $output = & $pwsh -NoLogo -NoProfile -File $validator `
            -RepositoryRoot $repository.Path `
            -ValidationMode PullRequest `
            -BaseRef $repository.Base `
            -EventPath $eventPath `
            -SchemaRoot $schemas `
            -PolicyPath $policy 2>&1 | Out-String
        $passed = $LASTEXITCODE -eq 0
        if ($passed -ne $ShouldPass) {
            throw "Case '$Name' expected pass=$ShouldPass but validator exit code was $LASTEXITCODE. Output: $output"
        }
        if ($output -notmatch [regex]::Escape($ExpectedMessage)) {
            throw "Case '$Name' did not report '$ExpectedMessage'. Output: $output"
        }
        Write-Host "PASS: $Name"
    }
    finally {
        if (Test-Path -LiteralPath $eventPath) { Remove-Item -LiteralPath $eventPath -Force }
        Remove-Item -LiteralPath $repository.Path -Recurse -Force
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

Invoke-PullRequestCase -Name 'rename source ownership' `
    -ExpectedMessage "hand-maintained path 'governance-source.md'" `
    -Mutate {
        param($path)
        $destination = Join-Path $path 'templates\entra\conditional-access\synthetic-policy-fixture\deployment\governance-source.md'
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        & git -C $path mv governance-source.md $destination
    }

Invoke-PullRequestCase -Name 'deleting all generated roots' `
    -ExpectedMessage 'Deleting catalog.json is prohibited' `
    -Mutate {
        param($path)
        & git -C $path rm -r --quiet templates catalog.json generated-manifest.json
    }

Invoke-ValidatorCase -Name 'orphan deployment derives incomplete artifact root' `
    -ShouldPass $false `
    -ExpectedMessage "is missing required file 'template.json'" `
    -Mutate {
        param($path)
        $orphan = Join-Path $path 'templates\entra\orphan-component\orphan-artifact\deployment'
        New-Item -ItemType Directory -Path $orphan -Force | Out-Null
        Write-Utf8Lf (Join-Path $orphan 'orphan.json') "{`n  `"fixtureOnly`": true`n}`n"
    }

Invoke-PullRequestCase -Name 'fabricated removal record' `
    -ExpectedMessage "priorVersion '9.9.9' does not match protected-base version '1.0.0'" `
    -Mutate {
        param($path)
        $manifestPath = Join-Path $path 'generated-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.removals = @(
            [ordered]@{
                id = 'synthetic-policy-fixture'
                priorVersion = '9.9.9'
                owner = 'Synthetic owner'
                reason = 'Synthetic fabricated removal regression'
                effectiveDate = '2026-01-01'
            }
        )
        Write-Utf8Lf $manifestPath (($manifest | ConvertTo-Json -Depth 20) + "`n")
    }

Invoke-ValidatorCase -Name 'duplicate removal records' -ShouldPass $false -Mutate {
    param($path)
    $manifestPath = Join-Path $path 'generated-manifest.json'
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $removal = [ordered]@{
        id = 'synthetic-policy-fixture'
        priorVersion = '1.0.0'
        owner = 'Synthetic owner'
        reason = 'Synthetic duplicate removal regression'
        effectiveDate = '2026-01-01'
    }
    $manifest.removals = @($removal, $removal)
    Write-Utf8Lf $manifestPath (($manifest | ConvertTo-Json -Depth 20) + "`n")
}

Invoke-PullRequestCase -Name 'pull request body leakage' `
    -ExpectedMessage 'pull request body contains a prohibited email address' `
    -Body "<!-- generated-publication -->`n## Publication summary`nContact operator@example.com at http://internal.example.internal/run`n## Artifacts`nSynthetic test`n## Removals`nNone`n## Validation`nSynthetic test"

Invoke-PullRequestCase -Name 'pull request title leakage' `
    -ExpectedMessage 'pull request title contains a prohibited tenant domain' `
    -Title '[Generated publication] tenant-name.onmicrosoft.com'

Invoke-PullRequestCase -Name 'publication version regression' `
    -ExpectedMessage "regresses protected-base version '1.0.0'" `
    -Mutate {
        param($path)
        $manifestPath = Join-Path $path 'generated-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.publicationVersion = '0.9.0'
        Write-Utf8Lf $manifestPath (($manifest | ConvertTo-Json -Depth 20) + "`n")
    }

Invoke-PullRequestCase -Name 'skipped publication version' `
    -ExpectedMessage "must advance from '1.0.0' by exactly one patch, minor, or major step" `
    -Mutate {
        param($path)
        $manifestPath = Join-Path $path 'generated-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.publicationVersion = '1.2.0'
        Write-Utf8Lf $manifestPath (($manifest | ConvertTo-Json -Depth 20) + "`n")
    }

Invoke-PullRequestCase -Name 'unchanged publication version' `
    -ExpectedMessage "must advance publicationVersion from '1.0.0'" `
    -Mutate {
        param($path)
        $manifestPath = Join-Path $path 'generated-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.publisher = 'Updated synthetic publisher'
        Write-Utf8Lf $manifestPath (($manifest | ConvertTo-Json -Depth 20) + "`n")
    }

Invoke-PullRequestCase -Name 'next patch publication version' `
    -ShouldPass $true `
    -Mutate {
        param($path)
        $manifestPath = Join-Path $path 'generated-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.publicationVersion = '1.0.1'
        Write-Utf8Lf $manifestPath (($manifest | ConvertTo-Json -Depth 20) + "`n")
    }

Invoke-PullRequestCase -Name 'next minor publication version' `
    -ShouldPass $true `
    -Mutate {
        param($path)
        $manifestPath = Join-Path $path 'generated-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.publicationVersion = '1.1.0'
        Write-Utf8Lf $manifestPath (($manifest | ConvertTo-Json -Depth 20) + "`n")
    }

Invoke-PullRequestCase -Name 'next major publication version' `
    -ShouldPass $true `
    -Mutate {
        param($path)
        $manifestPath = Join-Path $path 'generated-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.publicationVersion = '2.0.0'
        Write-Utf8Lf $manifestPath (($manifest | ConvertTo-Json -Depth 20) + "`n")
    }

Invoke-PullRequestCase -Name 'initial artifact retains bootstrap version' `
    -ShouldPass $true `
    -PrepareBase {
        param($path)
        Remove-Item -LiteralPath (Join-Path $path 'templates') -Recurse -Force
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'catalog.json') -Destination (Join-Path $path 'catalog.json') -Force
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'generated-manifest.json') -Destination (Join-Path $path 'generated-manifest.json') -Force
    } `
    -Mutate {
        param($path)
        Copy-Item -LiteralPath (Join-Path $fixture 'catalog.json') -Destination (Join-Path $path 'catalog.json') -Force
        Copy-Item -LiteralPath (Join-Path $fixture 'generated-manifest.json') -Destination (Join-Path $path 'generated-manifest.json') -Force
        Copy-Item -LiteralPath (Join-Path $fixture 'templates') -Destination (Join-Path $path 'templates') -Recurse -Force
    }

if ($testsRun -le 0) {
    throw 'Self-test executed zero cases.'
}
Write-Host "Self-test passed: $testsRun cases."
exit 0
