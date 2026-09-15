BeforeAll {
    $script:RepositoryRoot = Split-Path -Parent $PSScriptRoot
    $script:Validator = Join-Path $script:RepositoryRoot 'scripts\Validate-Publication.ps1'
    $script:Fixture = Join-Path $PSScriptRoot 'fixtures\valid'
    $script:Policy = Join-Path $script:RepositoryRoot '.github\publication-path-policy.json'
    $script:Schemas = Join-Path $script:RepositoryRoot 'schemas'
    $script:Pwsh = (Get-Process -Id $PID).Path

    function New-TestFixture {
        $path = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $path | Out-Null
        Copy-Item -Path (Join-Path $script:Fixture '*') -Destination $path -Recurse -Force
        return $path
    }

    function Invoke-TestValidator {
        param([string]$Path)
        & $script:Pwsh -NoLogo -NoProfile -File $script:Validator `
            -RepositoryRoot $Path `
            -ValidationMode Snapshot `
            -SchemaRoot $script:Schemas `
            -PolicyPath $script:Policy *> $null
        return $LASTEXITCODE
    }
}

Describe 'Public publication validator' {
    It 'accepts the deterministic synthetic bundle' {
        Invoke-TestValidator (New-TestFixture) | Should -Be 0
    }

    It 'rejects a forged manifest hash' {
        $path = New-TestFixture
        $manifestPath = Join-Path $path 'generated-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.files[0].sha256 = '0' * 64
        $manifest | ConvertTo-Json -Depth 20 | Set-Content $manifestPath -Encoding utf8NoBOM
        Invoke-TestValidator $path | Should -Not -Be 0
    }

    It 'rejects an unlisted generated file' {
        $path = New-TestFixture
        $scriptPath = Join-Path $path 'templates\entra\conditional-access\synthetic-policy-fixture\scripts'
        New-Item -ItemType Directory -Path $scriptPath | Out-Null
        Set-Content -LiteralPath (Join-Path $scriptPath 'unlisted.ps1') -Value "'fixture'" -Encoding utf8NoBOM
        Invoke-TestValidator $path | Should -Not -Be 0
    }

    It 'rejects manifest traversal' {
        $path = New-TestFixture
        $manifestPath = Join-Path $path 'generated-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.files[0].path = '../catalog.json'
        $manifest | ConvertTo-Json -Depth 20 | Set-Content $manifestPath -Encoding utf8NoBOM
        Invoke-TestValidator $path | Should -Not -Be 0
    }

    It 'rejects case-only collisions' {
        $path = New-TestFixture
        $manifestPath = Join-Path $path 'generated-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $collision = $manifest.files[1].PSObject.Copy()
        $collision.path = $collision.path.ToUpperInvariant()
        $manifest.files = @($manifest.files) + $collision
        $manifest | ConvertTo-Json -Depth 20 | Set-Content $manifestPath -Encoding utf8NoBOM
        Invoke-TestValidator $path | Should -Not -Be 0
    }

    It 'rejects unknown metadata fields' {
        $path = New-TestFixture
        $metadataPath = Join-Path $path 'templates\entra\conditional-access\synthetic-policy-fixture\metadata.json'
        $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
        $metadata | Add-Member -NotePropertyName unexpectedInternalField -NotePropertyValue 'must fail'
        $metadata | ConvertTo-Json -Depth 20 | Set-Content $metadataPath -Encoding utf8NoBOM
        Invoke-TestValidator $path | Should -Not -Be 0
    }

    It 'preserves unrelated catalog entries when a partial bundle is evaluated' {
        $path = New-TestFixture
        $catalogPath = Join-Path $path 'catalog.json'
        $catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
        $catalog.artifacts = @()
        $catalog | ConvertTo-Json -Depth 20 | Set-Content $catalogPath -Encoding utf8NoBOM
        Invoke-TestValidator $path | Should -Not -Be 0
    }
}
