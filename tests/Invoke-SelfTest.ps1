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
$publicTreeCleanupPaths = @(
    '.gitattributes',
    '.github/CODEOWNERS',
    '.github/publication-path-policy.json',
    '.github/pull_request_template.md',
    '.github/workflows/validate-publication.yml',
    'CONTRIBUTING.md',
    'Issues.md',
    'SECURITY.md',
    'SUPPORT.md',
    'catalog.json',
    'docs/PUBLICATION_CONTRACT.md',
    'docs/RELEASE_PROCESS.md',
    'docs/REPOSITORY_GOVERNANCE.md',
    'generated-manifest.json',
    'schemas/artifact-metadata.schema.json',
    'schemas/catalog.schema.json',
    'schemas/deployment-inputs.schema.json',
    'schemas/generated-manifest.schema.json',
    'scripts/Validate-Publication.ps1',
    'tests/Invoke-Pester.ps1',
    'tests/Invoke-SelfTest.ps1',
    'tests/PublicPublication.Tests.ps1',
    'tests/fixtures/valid/catalog.json',
    'tests/fixtures/valid/generated-manifest.json',
    'tests/fixtures/valid/templates/entra/conditional-access/synthetic-policy-fixture/README.md',
    'tests/fixtures/valid/templates/entra/conditional-access/synthetic-policy-fixture/metadata.json',
    'tests/fixtures/valid/templates/entra/conditional-access/synthetic-policy-fixture/template.json'
)

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

function Set-TestTreeFile {
    param(
        [string]$Root,
        [string]$RelativePath,
        [string]$Content
    )
    $path = Join-Path $Root $RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    Write-Utf8Lf $path $Content
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
        [string]$HeadRef = 'publication/synthetic-validation',
        [string]$HeadRepository = 'synthetic-owner/security-template',
        [switch]$NoAutoCommit,
        [string]$Body = "<!-- generated-publication -->`n## Publication summary`nSynthetic test`n## Artifacts`nSynthetic test`n## Removals`nNone`n## Validation`nSynthetic test"
    )
    $script:testsRun++
    $repository = New-PullRequestRepository -PrepareBase $PrepareBase
    $eventPath = Join-Path ([IO.Path]::GetTempPath()) "publication-event-$([guid]::NewGuid().ToString('N')).json"
    try {
        if ($Mutate -and $NoAutoCommit) {
            & $Mutate $repository.Path
        }
        elseif ($Mutate) {
            & $Mutate $repository.Path
            & git -C $repository.Path add --all
            & git -C $repository.Path commit --quiet -m 'candidate'
            if ($LASTEXITCODE -ne 0) { throw "Unable to commit mutation for '$Name'." }
        }
        $event = [ordered]@{
            pull_request = [ordered]@{
                title = $Title
                body = $Body
                head = [ordered]@{
                    ref = $HeadRef
                    repo = [ordered]@{ full_name = $HeadRepository }
                }
            }
            repository = [ordered]@{ full_name = 'synthetic-owner/security-template' }
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

$publicTreeTitle = '[Public tree sync] Synthetic public tree update'
$publicTreeBody = "<!-- public-tree-sync -->`nSynthetic public tree sync."
$preparePublicTreeBase = {
    param($path)
    Get-ChildItem -LiteralPath $path -Force | Remove-Item -Recurse -Force
    & $script:SetPublicTreeBaseFiles $path
}
$script:SetPublicTreeBaseFiles = {
    param($path)
    Set-TestTreeFile $path 'README.md' "# Synthetic public README`n"
    Set-TestTreeFile $path 'LICENSE' "Synthetic license.`n"
    Set-TestTreeFile $path '.github/ISSUE_TEMPLATE/bug_report.yml' "name: Bug report`n"
    Set-TestTreeFile $path '.github/ISSUE_TEMPLATE/config.yml' "blank_issues_enabled: false`n"
    Set-TestTreeFile $path '.github/ISSUE_TEMPLATE/documentation_or_licensing_correction.yml' "name: Documentation correction`n"
    Set-TestTreeFile $path '.github/ISSUE_TEMPLATE/feature_or_policy_request.yml' "name: Feature request`n"
    Set-TestTreeFile $path 'intune/baseline/existing.json' "{`n  `"fixtureOnly`": true`n}`n"
    Set-TestTreeFile $path 'intune/baseline/retired.md' "Synthetic retired guidance.`n"
}
$preparePublicTreeCleanupBase = {
    param($path)
    Get-ChildItem -LiteralPath $path -Force | Remove-Item -Recurse -Force
    & $script:SetPublicTreeBaseFiles $path
    foreach ($relativePath in $script:PublicTreeCleanupPaths) {
        Set-TestTreeFile $path $relativePath "Legacy path slated for the approved cleanup.`n"
    }
}
$script:PublicTreeCleanupPaths = $publicTreeCleanupPaths
$script:PreparePublicTreeCleanupBase = $preparePublicTreeCleanupBase
$preparePublicTreeUnexpectedDeletionBase = {
    param($path)
    & $script:PreparePublicTreeCleanupBase $path
    Set-TestTreeFile $path 'unexpected-legacy.md' "Not approved for deletion.`n"
}
$commitIndexEntries = {
    param([string]$Path, [string[]]$Entries)
    foreach ($entry in $Entries) {
        $parts = $entry -split '\|', 3
        $blob = ($parts[2] | & git -C $Path hash-object -w --stdin)
        & git -C $Path update-index --add --cacheinfo "$($parts[0]),$blob,$($parts[1])"
        if ($LASTEXITCODE -ne 0) { throw "Unable to stage index entry '$($parts[1])'." }
    }
    & git -C $Path commit --quiet -m 'candidate'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to commit index-only candidate.' }
}

Invoke-PullRequestCase -Name 'future public tree sync allows README and intune changes' `
    -ShouldPass $true `
    -ExpectedMessage 'Validating public tree sync pull request' `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Write-Utf8Lf (Join-Path $path 'README.md') "# Synthetic public README`n`nUpdated overview.`n"
        Write-Utf8Lf (Join-Path $path 'intune\baseline\existing.json') "{`n  `"fixtureOnly`": false`n}`n"
        New-Item -ItemType Directory -Path (Join-Path $path 'intune\compliance') -Force | Out-Null
        Write-Utf8Lf (Join-Path $path 'intune\compliance\new-policy.md') "# Synthetic compliance guidance`n"
        Remove-Item -LiteralPath (Join-Path $path 'intune\baseline\retired.md')
    }

Invoke-PullRequestCase -Name 'public tree sync allows the exact one-time legacy cleanup set' `
    -ShouldPass $true `
    -ExpectedMessage 'Validating public tree sync pull request' `
    -PrepareBase $preparePublicTreeCleanupBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        foreach ($relativePath in $script:PublicTreeCleanupPaths) {
            Remove-Item -LiteralPath (Join-Path $path $relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)) -Force
        }
        Write-Utf8Lf (Join-Path $path 'README.md') "# Clean public README`n"
        Write-Utf8Lf (Join-Path $path 'intune\baseline\existing.json') "{`n  `"fixtureOnly`": false`n}`n"
    }

Invoke-PullRequestCase -Name 'public tree sync rejects an unapproved extra cleanup deletion' `
    -ExpectedMessage 'exact one-time approved cleanup set' `
    -PrepareBase $preparePublicTreeUnexpectedDeletionBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        foreach ($relativePath in $script:PublicTreeCleanupPaths) {
            Remove-Item -LiteralPath (Join-Path $path $relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)) -Force
        }
        Remove-Item -LiteralPath (Join-Path $path 'unexpected-legacy.md') -Force
    }

Invoke-PullRequestCase -Name 'public tree sync rejects an unexpected cleanup addition' `
    -ExpectedMessage "outside the approved public root" `
    -PrepareBase $preparePublicTreeCleanupBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        foreach ($relativePath in $script:PublicTreeCleanupPaths) {
            Remove-Item -LiteralPath (Join-Path $path $relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)) -Force
        }
        Write-Utf8Lf (Join-Path $path 'unexpected-public.md') "Not in the public root allowlist.`n"
    }

Invoke-PullRequestCase -Name 'public tree sync rejects changing an approved legacy file instead of deleting it' `
    -ExpectedMessage "Public tree sync changed prohibited path '.gitattributes'" `
    -PrepareBase $preparePublicTreeCleanupBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        foreach ($relativePath in $script:PublicTreeCleanupPaths | Where-Object { $_ -cne '.gitattributes' }) {
            Remove-Item -LiteralPath (Join-Path $path $relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)) -Force
        }
        Write-Utf8Lf (Join-Path $path '.gitattributes') "Changed rather than deleted.`n"
    }

Invoke-PullRequestCase -Name 'public tree sync rejects LICENSE modification' `
    -ExpectedMessage "Public tree sync changed prohibited path 'LICENSE'" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Write-Utf8Lf (Join-Path $path 'LICENSE') "Modified synthetic license.`n"
    }

Invoke-PullRequestCase -Name 'public tree sync rejects governance workflow change' `
    -ExpectedMessage "Public tree sync changed prohibited path '.github/workflows/sync.yml'" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        New-Item -ItemType Directory -Path (Join-Path $path '.github\workflows') -Force | Out-Null
        Write-Utf8Lf (Join-Path $path '.github\workflows\sync.yml') "name: synthetic`n"
    }

Invoke-PullRequestCase -Name 'public tree sync rejects LICENSE deletion' `
    -ExpectedMessage "Public tree sync changed prohibited path 'LICENSE'" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Remove-Item -LiteralPath (Join-Path $path 'LICENSE')
    }

Invoke-PullRequestCase -Name 'public tree sync rejects issue template modification' `
    -ExpectedMessage "Public tree sync changed prohibited path '.github/ISSUE_TEMPLATE/bug_report.yml'" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Write-Utf8Lf (Join-Path $path '.github\ISSUE_TEMPLATE\bug_report.yml') "Modified issue template.`n"
    }

Invoke-PullRequestCase -Name 'public tree sync rejects issue template deletion' `
    -ExpectedMessage "Public tree sync changed prohibited path '.github/ISSUE_TEMPLATE/config.yml'" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Remove-Item -LiteralPath (Join-Path $path '.github\ISSUE_TEMPLATE\config.yml')
    }

Invoke-PullRequestCase -Name 'public tree sync rejects adding an issue template' `
    -ExpectedMessage 'must preserve LICENSE and every .github/ISSUE_TEMPLATE/** path byte-for-byte' `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Write-Utf8Lf (Join-Path $path '.github\ISSUE_TEMPLATE\unexpected.yml') "name: Unexpected template`n"
    }

Invoke-PullRequestCase -Name 'public tree sync rejects unrelated file change' `
    -ExpectedMessage "Public tree sync changed prohibited path 'governance-source.md'" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Write-Utf8Lf (Join-Path $path 'governance-source.md') "Tampered governance source.`n"
    }

Invoke-PullRequestCase -Name 'public tree sync rejects generated catalog change' `
    -ExpectedMessage "Public tree sync changed prohibited path 'catalog.json'" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Write-Utf8Lf (Join-Path $path 'catalog.json') "{`n  `"generatedAt`": `"2026-01-02T00:00:00Z`"`n}`n"
    }

Invoke-PullRequestCase -Name 'public tree sync rejects README deletion' `
    -ExpectedMessage 'Public tree sync cannot delete README.md' `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Remove-Item -LiteralPath (Join-Path $path 'README.md')
    }

Invoke-PullRequestCase -Name 'public tree sync rejects rename out of intune' `
    -ExpectedMessage "Public tree sync changed prohibited path 'scripts/existing.json'" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        New-Item -ItemType Directory -Path (Join-Path $path 'scripts') -Force | Out-Null
        & git -C $path mv intune/baseline/existing.json scripts/existing.json
    }

Invoke-PullRequestCase -Name 'public tree sync rejects unsafe intune path' `
    -ExpectedMessage "Public tree sync path 'intune/baseline/unsafe name.md' is unsafe" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Write-Utf8Lf (Join-Path $path 'intune\baseline\unsafe name.md') "Synthetic.`n"
    }

Invoke-PullRequestCase -Name 'public tree sync rejects intune symlink' `
    -ExpectedMessage "Public tree sync path 'intune/baseline/link.json' is a symlink" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -NoAutoCommit `
    -Mutate {
        param($path)
        & $commitIndexEntries $path @('120000|intune/baseline/link.json|../../LICENSE')
    }

Invoke-PullRequestCase -Name 'public tree sync rejects intune case collision' `
    -ExpectedMessage "Public tree sync paths 'intune/baseline/Policy.json' and 'intune/baseline/policy.json' collide" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -NoAutoCommit `
    -Mutate {
        param($path)
        & $commitIndexEntries $path @(
            '100644|intune/baseline/Policy.json|{}',
            '100644|intune/baseline/policy.json|[]'
        )
    }

Invoke-PullRequestCase -Name 'public tree sync rejects private key content' `
    -ExpectedMessage "Public tree sync file 'intune/baseline/key.md' contains a private key" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Write-Utf8Lf (Join-Path $path 'intune\baseline\key.md') "-----BEGIN PRIVATE KEY-----`nsynthetic`n"
    }

Invoke-PullRequestCase -Name 'public tree sync signals from a fork fall back to generated validation' `
    -ExpectedMessage "Generated publication changed hand-maintained path 'README.md'" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree' `
    -HeadRepository 'fork-owner/security-template' `
    -Mutate {
        param($path)
        Write-Utf8Lf (Join-Path $path 'README.md') "# Forked README`n"
    }

Invoke-PullRequestCase -Name 'public tree branch without marker uses generated validation' `
    -ExpectedMessage "Generated publication changed hand-maintained path 'README.md'" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body 'Synthetic public tree sync without marker.' -HeadRef 'publication/public-tree' `
    -Mutate {
        param($path)
        Write-Utf8Lf (Join-Path $path 'README.md') "# Updated README`n"
    }

Invoke-PullRequestCase -Name 'public tree signals on another branch use generated validation' `
    -ExpectedMessage "Generated publication changed hand-maintained path 'README.md'" `
    -PrepareBase $preparePublicTreeBase `
    -Title $publicTreeTitle -Body $publicTreeBody -HeadRef 'publication/public-tree-other' `
    -Mutate {
        param($path)
        Write-Utf8Lf (Join-Path $path 'README.md') "# Updated README`n"
    }

if ($testsRun -le 0) {
    throw 'Self-test executed zero cases.'
}
Write-Host "Self-test passed: $testsRun cases."
exit 0
