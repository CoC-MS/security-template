[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),

    [Parameter()]
    [string]$BaseRef,

    [Parameter()]
    [string]$EventPath = $env:GITHUB_EVENT_PATH,

    [Parameter()]
    [ValidateSet('Auto', 'Snapshot', 'PullRequest')]
    [string]$ValidationMode = 'Auto',

    [Parameter()]
    [string]$ReportPath,

    [Parameter()]
    [string]$SchemaRoot,

    [Parameter()]
    [string]$PolicyPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Failures = [System.Collections.Generic.List[string]]::new()
$script:Warnings = [System.Collections.Generic.List[string]]::new()
$utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
$allowedScriptExtensions = @('.ps1', '.sh')
$forbiddenExtensions = @(
    '.7z', '.a', '.apk', '.app', '.bin', '.cab', '.cer', '.class', '.com',
    '.crt', '.der', '.dll', '.dmg', '.exe', '.gz', '.iso', '.jar', '.key',
    '.msi', '.p12', '.pfx', '.pkg', '.rar', '.so', '.tar', '.war', '.zip'
)
$reservedWindowsNames = '^(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)'

function Add-Failure {
    param([string]$Message)
    $script:Failures.Add($Message)
    Write-Host "::error::$Message"
}

function Add-Warning {
    param([string]$Message)
    $script:Warnings.Add($Message)
    Write-Host "::warning::$Message"
}

function Convert-ToRelativePath {
    param([string]$Path)
    [System.IO.Path]::GetRelativePath($RepositoryRoot, $Path).Replace('\', '/')
}

function Get-GeneratedFiles {
    $files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    foreach ($name in @('catalog.json', 'generated-manifest.json')) {
        $path = Join-Path $RepositoryRoot $name
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $files.Add((Get-Item -LiteralPath $path))
        }
    }

    $templates = Join-Path $RepositoryRoot 'templates'
    if (Test-Path -LiteralPath $templates -PathType Container) {
        Get-ChildItem -LiteralPath $templates -File -Recurse | ForEach-Object { $files.Add($_) }
    }
    return $files
}

function Test-DeterministicText {
    param([System.IO.FileInfo]$File)
    $relative = Convert-ToRelativePath $File.FullName
    $bytes = [System.IO.File]::ReadAllBytes($File.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Add-Failure "$relative uses a UTF-8 BOM; generated text must be UTF-8 without BOM."
    }
    try {
        $text = $utf8Strict.GetString($bytes)
    }
    catch {
        Add-Failure "$relative is not valid UTF-8."
        return $null
    }
    if ($text.Contains("`r")) {
        Add-Failure "$relative uses CR or CRLF line endings; generated text must use LF."
    }
    if ($bytes.Length -gt 0 -and -not $text.EndsWith("`n", [System.StringComparison]::Ordinal)) {
        Add-Failure "$relative must end with a newline."
    }
    return $text
}

function Read-JsonFile {
    param(
        [string]$Path,
        [string]$SchemaName
    )
    $relative = Convert-ToRelativePath $Path
    try {
        $raw = [System.IO.File]::ReadAllText($Path, $utf8Strict)
        $schemaPath = Join-Path $SchemaRoot $SchemaName
        if (-not (Test-Json -Json $raw -SchemaFile $schemaPath -ErrorAction Stop)) {
            Add-Failure "$relative does not conform to $SchemaName."
        }
        return $raw | ConvertFrom-Json -Depth 100
    }
    catch {
        Add-Failure "$relative is invalid: $($_.Exception.Message)"
        return $null
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-GeneratedPath {
    param([string]$Path)
    $normalized = $Path.Replace('\', '/').TrimStart('./')
    $matches = @($script:PublicationPolicy.generatedPathPatterns | Where-Object {
        $normalized -cmatch [string]$_
    })
    return $matches.Count -eq 1
}

function Test-SafeRelativePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or
        [System.IO.Path]::IsPathRooted($Path) -or
        $Path.Contains('\') -or
        $Path -match '(^|/)\.\.?(/|$)' -or
        $Path -notmatch '^[A-Za-z0-9._/-]+$' -or
        $Path.Contains('//')) {
        return $false
    }
    foreach ($segment in $Path.Split('/')) {
        if ($segment -match $reservedWindowsNames -or $segment.EndsWith('.') -or $segment.EndsWith(' ')) {
            return $false
        }
    }
    return $true
}

function Test-SchemaContracts {
    $expectedDraft = 'https://json-schema.org/draft/2020-12/schema'
    foreach ($schemaFile in Get-ChildItem -LiteralPath $SchemaRoot -Filter '*.schema.json' -File) {
        try {
            $schema = Get-Content -LiteralPath $schemaFile.FullName -Raw | ConvertFrom-Json -Depth 100
            if ($schema.'$schema' -ne $expectedDraft) {
                Add-Failure "$($schemaFile.Name) must pin JSON Schema draft 2020-12."
            }
            $raw = Get-Content -LiteralPath $schemaFile.FullName -Raw
            foreach ($match in [regex]::Matches($raw, '"\$ref"\s*:\s*"([^"]+)"')) {
                if (-not $match.Groups[1].Value.StartsWith('#/', [System.StringComparison]::Ordinal)) {
                    Add-Failure "$($schemaFile.Name) contains remote or non-local `$ref '$($match.Groups[1].Value)'."
                }
            }
        }
        catch {
            Add-Failure "Schema '$($schemaFile.Name)' is invalid JSON: $($_.Exception.Message)"
        }
    }
}

function Test-NormalizedCollisions {
    param([string[]]$Paths)
    $seen = @{}
    foreach ($path in $Paths) {
        $normalized = $path.Normalize([System.Text.NormalizationForm]::FormC).ToUpperInvariant()
        if ($seen.ContainsKey($normalized) -and $seen[$normalized] -cne $path) {
            Add-Failure "Generated paths '$($seen[$normalized])' and '$path' collide by case or Unicode normalization."
        }
        else {
            $seen[$normalized] = $path
        }
    }
}

function Get-OrdinalSorted {
    param([string[]]$Values)
    $copy = [string[]]@($Values)
    [Array]::Sort($copy, [StringComparer]::Ordinal)
    return $copy
}

function Test-PropertyOrder {
    param(
        [object]$Object,
        [string[]]$Expected,
        [string]$Location
    )
    $actual = @($Object.PSObject.Properties.Name)
    $expectedPresent = @($Expected | Where-Object { $actual -ccontains $_ })
    if (($actual -join "`n") -cne ($expectedPresent -join "`n")) {
        Add-Failure "$Location properties are not in deterministic contract order."
    }
}

function Test-ContentSafety {
    param(
        [string]$Relative,
        [string]$Text
    )
    $checks = [ordered]@{
        'GUID or tenant identifier' = '(?i)(?<![0-9a-f])[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}(?![0-9a-f])'
        'email address' = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
        'tenant domain' = '(?i)\b[a-z0-9-]+\.onmicrosoft\.com\b'
        'private or internal URL' = '(?i)https?://(?:localhost|127\.0\.0\.1|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(?:1[6-9]|2\d|3[01])\.\d+\.\d+|[^/\s]+\.internal)(?::\d+)?(?:/|\b)'
        'secret-like value' = '(?i)(?:client[_-]?secret|api[_-]?key|access[_-]?token|password)\s*["'']?\s*[:=]\s*["''][^"'']{8,}["'']'
        'private key' = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
        'internal provenance' = '(?i)(?:github\.com/[^\s"'']*(?:internal|private)|(?:internal|private)[-_ ](?:repository|workflow|runner))'
    }
    foreach ($entry in $checks.GetEnumerator()) {
        if ($Text -match $entry.Value) {
            Add-Failure "$Relative contains a prohibited $($entry.Key). Use synthetic public-safe values."
        }
    }

    foreach ($match in [regex]::Matches($Text, 'https?://[^\s<>"'')\]]+')) {
        $rawUrl = $match.Value.TrimEnd('.', ',', ';')
        try {
            $uri = [uri]$rawUrl
            if ($uri.Scheme -ne 'https') {
                Add-Failure "$Relative contains a non-HTTPS public link: $rawUrl"
            }
            if ($uri.Host -match '(?i)(^localhost$|\.local$|\.internal$)' -or
                $uri.IsLoopback -or
                $uri.Host -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)') {
                Add-Failure "$Relative contains a non-public link: $rawUrl"
            }
        }
        catch {
            Add-Failure "$Relative contains a malformed URL: $rawUrl"
        }
    }
}

function Test-ScriptSafety {
    param(
        [System.IO.FileInfo]$File,
        [string]$Text
    )
    $relative = Convert-ToRelativePath $File.FullName
    if ($File.Extension -eq '.ps1') {
        $tokens = $null
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $File.FullName,
            [ref]$tokens,
            [ref]$parseErrors
        )
        foreach ($parseError in $parseErrors) {
            Add-Failure "$relative has PowerShell syntax error at line $($parseError.Extent.StartLineNumber): $($parseError.Message)"
        }
    }
    elseif ($File.Extension -eq '.sh') {
        $bash = Get-Command bash -ErrorAction SilentlyContinue
        if ($null -ne $bash) {
            & $bash.Source -n $File.FullName
            if ($LASTEXITCODE -ne 0) {
                Add-Failure "$relative failed 'bash -n' syntax validation."
            }
        }
        else {
            Add-Warning "$relative could not receive bash syntax validation because bash is unavailable."
        }
    }

    $unsafePatterns = [ordered]@{
        'dynamic PowerShell execution' = '(?i)\b(?:Invoke-Expression|iex)\b'
        'encoded PowerShell command' = '(?i)-(?:EncodedCommand|enc)\b'
        'execution-policy bypass' = '(?i)-ExecutionPolicy\s+Bypass\b'
        'download piped to shell' = '(?i)(?:curl|wget|Invoke-WebRequest|iwr).{0,200}\|\s*(?:sh|bash|pwsh|powershell)\b'
        'recursive root deletion' = '(?i)\brm\s+-[a-z]*r[a-z]*f[a-z]*\s+/(?:\s|$)'
        'world-writable permissions' = '(?i)\bchmod\s+(?:-R\s+)?777\b'
        'disabled TLS validation' = '(?i)(?:TrustAllCertsPolicy|ServerCertificateValidationCallback|--insecure\b|-k\b)'
    }
    foreach ($entry in $unsafePatterns.GetEnumerator()) {
        if ($Text -match $entry.Value) {
            Add-Failure "$relative contains prohibited $($entry.Key)."
        }
    }
}

function Get-PullRequestContext {
    $context = [ordered]@{
        IsGenerated = $false
        Title = ''
        Body = ''
        Changed = @()
        Deleted = @()
        Touched = @()
    }
    if ($ValidationMode -eq 'Snapshot') {
        return $context
    }

    if ($EventPath -and (Test-Path -LiteralPath $EventPath -PathType Leaf)) {
        try {
            $event = Get-Content -LiteralPath $EventPath -Raw | ConvertFrom-Json -Depth 20
            if ($null -ne $event.pull_request) {
                $title = [string]$event.pull_request.title
                $context.Title = $title
                $context.Body = [string]$event.pull_request.body
                $actor = [string]$event.sender.login
                $head = [string]$event.pull_request.head.ref
                $context.IsGenerated =
                    $title.StartsWith('[Generated publication]', [System.StringComparison]::OrdinalIgnoreCase) -or
                    $context.Body.Contains('<!-- generated-publication -->') -or
                    $actor.EndsWith('[bot]', [System.StringComparison]::OrdinalIgnoreCase) -or
                    $head.StartsWith('publication/', [System.StringComparison]::OrdinalIgnoreCase)
            }
        }
        catch {
            Add-Failure "Unable to parse GitHub event payload '$EventPath': $($_.Exception.Message)"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($BaseRef)) {
        try {
            $nameStatus = & git -C $RepositoryRoot diff --name-status --find-renames "$BaseRef...HEAD"
            if ($LASTEXITCODE -ne 0) {
                throw "git diff exited with code $LASTEXITCODE"
            }
            $changed = [System.Collections.Generic.List[string]]::new()
            $deleted = [System.Collections.Generic.List[string]]::new()
            $touched = [System.Collections.Generic.List[string]]::new()
            foreach ($line in $nameStatus) {
                $parts = $line -split "`t"
                if ($parts.Count -lt 2) { continue }
                $status = $parts[0]
                $path = if ($status.StartsWith('R')) { $parts[2] } else { $parts[1] }
                $path = $path.Replace('\', '/')
                $changed.Add($path)
                $touched.Add($path)
                if ($status -eq 'D') { $deleted.Add($path) }
                if ($status.StartsWith('R')) {
                    $sourcePath = $parts[1].Replace('\', '/')
                    $deleted.Add($sourcePath)
                    $touched.Add($sourcePath)
                }
            }
            $context.Changed = $changed.ToArray()
            $context.Deleted = $deleted.ToArray()
            $context.Touched = $touched.ToArray()
        }
        catch {
            Add-Failure "Unable to determine pull request changes from '$BaseRef': $($_.Exception.Message)"
        }
    }
    elseif ($ValidationMode -eq 'PullRequest') {
        Add-Failure 'PullRequest validation requires -BaseRef.'
    }
    return $context
}

function Get-BasePublicationState {
    $state = [ordered]@{
        Files = @()
        MetadataById = @{}
        HasCatalog = $false
        HasManifest = $false
    }
    if ($ValidationMode -ne 'PullRequest' -or [string]::IsNullOrWhiteSpace($BaseRef)) {
        return $state
    }
    try {
        $files = @(& git -C $RepositoryRoot ls-tree -r --name-only $BaseRef)
        if ($LASTEXITCODE -ne 0) { throw "git ls-tree exited with code $LASTEXITCODE" }
        $state.Files = @($files | ForEach-Object { $_.Replace('\', '/') })
        $state.HasCatalog = $state.Files -ccontains 'catalog.json'
        $state.HasManifest = $state.Files -ccontains 'generated-manifest.json'
        foreach ($path in $state.Files) {
            if ($path -notmatch '^templates/(?:intune|defender|purview|entra)/[^/]+/[^/]+/metadata\.json$') {
                continue
            }
            $raw = (& git -C $RepositoryRoot show "${BaseRef}:$path") -join "`n"
            if ($LASTEXITCODE -ne 0) { throw "git show failed for $path" }
            $metadata = $raw | ConvertFrom-Json -Depth 100
            $state.MetadataById[[string]$metadata.id] = [ordered]@{
                Version = [string]$metadata.artifactVersion
                Path = $path
            }
        }
    }
    catch {
        Add-Failure "Unable to inspect protected base publication state '$BaseRef': $($_.Exception.Message)"
    }
    return $state
}

$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$sourceRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SchemaRoot)) {
    $SchemaRoot = Join-Path $sourceRoot 'schemas'
}
$SchemaRoot = (Resolve-Path -LiteralPath $SchemaRoot).Path
if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
    $PolicyPath = Join-Path $sourceRoot '.github\publication-path-policy.json'
}
try {
    $script:PublicationPolicy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json -Depth 20
    if ($script:PublicationPolicy.schemaVersion -ne '1.0.0' -or
        @($script:PublicationPolicy.generatedPathPatterns).Count -eq 0) {
        throw 'unsupported or empty publication path policy'
    }
}
catch {
    Add-Failure "Publication path policy '$PolicyPath' is invalid: $($_.Exception.Message)"
    $script:PublicationPolicy = [pscustomobject]@{ generatedPathPatterns = @() }
}
if ($ValidationMode -eq 'Auto') {
    $ValidationMode = if ($BaseRef) { 'PullRequest' } else { 'Snapshot' }
}

Write-Host "Validating public publication contract in $RepositoryRoot"
Test-SchemaContracts
$pr = Get-PullRequestContext
$baseState = Get-BasePublicationState
if ($pr.Title) { Test-ContentSafety 'pull request title' $pr.Title }
if ($pr.Body) { Test-ContentSafety 'pull request body' $pr.Body }
if ($pr.IsGenerated) {
    foreach ($path in $pr.Touched) {
        if (-not (Test-GeneratedPath $path)) {
            Add-Failure "Generated publication changed hand-maintained path '$path'. Split governance changes from publication."
        }
    }
    foreach ($heading in @(
        '## Publication summary',
        '## Artifacts',
        '## Removals',
        '## Validation'
    )) {
        if (-not $pr.Body.Contains($heading)) {
            Add-Failure "Generated publication PR body is missing '$heading'."
        }
    }
}
elseif ($pr.Touched.Count -gt 0) {
    foreach ($path in $pr.Touched) {
        if (Test-GeneratedPath $path) {
            Add-Failure "Hand-maintained pull request changed generated path '$path'. Use the controlled generated publication marker and report."
        }
    }
}

$generatedFiles = @(Get-GeneratedFiles)
$generatedRelativePaths = @($generatedFiles | ForEach-Object { Convert-ToRelativePath $_.FullName })
Test-NormalizedCollisions $generatedRelativePaths
$templatesRoot = Join-Path $RepositoryRoot 'templates'
if (Test-Path -LiteralPath $templatesRoot -PathType Container) {
    Get-ChildItem -LiteralPath $templatesRoot -Recurse -Force | Where-Object {
        ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    } | ForEach-Object {
        Add-Failure "Generated path '$(Convert-ToRelativePath $_.FullName)' is a symlink/reparse point."
    }
}
foreach ($file in $generatedFiles) {
    $relative = Convert-ToRelativePath $file.FullName
    if (-not (Test-SafeRelativePath $relative)) {
        Add-Failure "Generated path '$relative' is unsafe."
    }
    if (($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Add-Failure "Generated path '$relative' is a symlink/reparse point."
    }
    if ($forbiddenExtensions -contains $file.Extension.ToLowerInvariant()) {
        Add-Failure "Generated path '$relative' uses forbidden binary extension '$($file.Extension)'."
    }
    if ($relative -match '/scripts/' -and $allowedScriptExtensions -notcontains $file.Extension.ToLowerInvariant()) {
        Add-Failure "Generated script '$relative' must use a supported .ps1 or .sh extension."
    }
    if ($file.Length -gt 5MB) {
        Add-Failure "Generated file '$relative' exceeds the 5 MiB limit."
    }
    $text = Test-DeterministicText $file
    if ($null -ne $text) {
        Test-ContentSafety $relative $text
        if ($allowedScriptExtensions -contains $file.Extension.ToLowerInvariant()) {
            Test-ScriptSafety $file $text
        }
    }
}

$artifactDirectories = @()
if (Test-Path -LiteralPath $templatesRoot -PathType Container) {
    $artifactRootPaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($file in Get-ChildItem -LiteralPath $templatesRoot -File -Recurse) {
        $relative = Convert-ToRelativePath $file.FullName
        $parts = $relative.Split('/')
        if ($parts.Count -lt 5) {
            Add-Failure "Generated file '$relative' is not beneath a canonical artifact root."
            continue
        }
        [void]$artifactRootPaths.Add(($parts[0..3] -join '/'))
    }
    $artifactDirectories = @($artifactRootPaths | ForEach-Object {
        Get-Item -LiteralPath (Join-Path $RepositoryRoot $_.Replace('/', '\'))
    })
}

$metadataById = @{}
foreach ($directory in $artifactDirectories) {
    $relativeDirectory = Convert-ToRelativePath $directory.FullName
    if ($relativeDirectory -notmatch '^templates/(intune|defender|purview|entra)/([a-z0-9]+(?:-[a-z0-9]+)*)/([a-z0-9]+(?:-[a-z0-9]+)*)$') {
        Add-Failure "Artifact directory '$relativeDirectory' must match templates/<solution-area>/<component>/<stable-artifact-id>."
        continue
    }
    $solutionArea = $Matches[1]
    $component = $Matches[2]
    $stableId = $Matches[3]
    foreach ($required in @('template.json', 'metadata.json', 'README.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $directory.FullName $required) -PathType Leaf)) {
            Add-Failure "$relativeDirectory is missing required file '$required'."
        }
    }
    $allowedTopLevel = @('template.json', 'metadata.json', 'README.md', 'deployment', 'scripts')
    Get-ChildItem -LiteralPath $directory.FullName | ForEach-Object {
        if ($allowedTopLevel -notcontains $_.Name) {
            Add-Failure "$relativeDirectory contains undeclared top-level entry '$($_.Name)'."
        }
    }

    $metadataPath = Join-Path $directory.FullName 'metadata.json'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) { continue }
    $metadata = Read-JsonFile $metadataPath 'artifact-metadata.schema.json'
    if ($null -eq $metadata) { continue }
    Test-PropertyOrder $metadata @(
        'id', 'schemaVersion', 'artifactVersion', 'solutionArea', 'component',
        'title', 'description', 'platforms', 'scope', 'impact', 'prerequisites',
        'licensing', 'permissions', 'dependencies', 'incompatibilities',
        'deployment', 'validation', 'pilot', 'rollback', 'compatibility',
        'limitations', 'references', 'lastValidated', 'integrity', 'provenance',
        'lifecycle'
    ) "$relativeDirectory/metadata.json"
    if ($metadata.id -ne $stableId) { Add-Failure "$relativeDirectory metadata id '$($metadata.id)' does not match its path." }
    if ($metadata.solutionArea -ne $solutionArea) { Add-Failure "$relativeDirectory solutionArea '$($metadata.solutionArea)' does not match its path." }
    if ($metadata.component -ne $component) { Add-Failure "$relativeDirectory component '$($metadata.component)' does not match its path." }
    $validatedDate = [datetime]::MinValue
    if (-not [datetime]::TryParseExact(
        [string]$metadata.lastValidated,
        'yyyy-MM-dd',
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None,
        [ref]$validatedDate
    )) {
        Add-Failure "$relativeDirectory lastValidated is not a real yyyy-MM-dd date."
    }
    elseif ($validatedDate.Date -gt [datetime]::UtcNow.Date) {
        Add-Failure "$relativeDirectory lastValidated cannot be in the future."
    }
    if ($metadataById.ContainsKey([string]$metadata.id)) {
        Add-Failure "Stable artifact id '$($metadata.id)' is duplicated."
    }
    else {
        $metadataById[[string]$metadata.id] = [ordered]@{
            Metadata = $metadata
            Directory = $relativeDirectory
            MetadataPath = $metadataPath
        }
    }

    $templatePath = Join-Path $directory.FullName 'template.json'
    if (Test-Path -LiteralPath $templatePath -PathType Leaf) {
        try {
            Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json -Depth 100 | Out-Null
        }
        catch {
            Add-Failure "$relativeDirectory/template.json is not valid JSON: $($_.Exception.Message)"
        }
        $actualTemplateHash = Get-Sha256 $templatePath
        if ($metadata.integrity.templateSha256 -ne $actualTemplateHash) {
            Add-Failure "$relativeDirectory metadata templateSha256 does not match template.json."
        }
    }
    $optionalFiles = @(
        Get-ChildItem -LiteralPath $directory.FullName -File -Recurse |
            Where-Object { $_.Name -notin @('template.json', 'metadata.json', 'README.md') }
    )
    $declaredAdditional = @{}
    if ($null -ne $metadata.integrity.additionalFiles) {
        foreach ($property in $metadata.integrity.additionalFiles.PSObject.Properties) {
            $declaredAdditional[$property.Name] = [string]$property.Value
        }
    }
    foreach ($optionalFile in $optionalFiles) {
        $optionalRelative = [System.IO.Path]::GetRelativePath($directory.FullName, $optionalFile.FullName).Replace('\', '/')
        if (-not $declaredAdditional.ContainsKey($optionalRelative)) {
            Add-Failure "$relativeDirectory/$optionalRelative is missing from metadata integrity.additionalFiles."
        }
        elseif ($declaredAdditional[$optionalRelative] -ne (Get-Sha256 $optionalFile.FullName)) {
            Add-Failure "$relativeDirectory metadata hash is incorrect for '$optionalRelative'."
        }
    }
    foreach ($declaredPath in $declaredAdditional.Keys) {
        if (-not (Test-SafeRelativePath $declaredPath) -or $declaredPath -notmatch '^(deployment|scripts)/') {
            Add-Failure "$relativeDirectory declares unsafe additional file '$declaredPath'."
            continue
        }
        if (-not (Test-Path -LiteralPath (Join-Path $directory.FullName $declaredPath.Replace('/', '\')) -PathType Leaf)) {
            Add-Failure "$relativeDirectory metadata declares missing additional file '$declaredPath'."
        }
    }

    $readmePath = Join-Path $directory.FullName 'README.md'
    if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
        $readme = Get-Content -LiteralPath $readmePath -Raw
        foreach ($section in @('Summary', 'Deployment', 'Validation', 'Pilot', 'Rollback', 'Limitations')) {
            if ($readme -notmatch "(?im)^#{1,3}\s+$([regex]::Escape($section))\s*$") {
                Add-Failure "$relativeDirectory/README.md is missing the '$section' heading."
            }
        }
    }

    $inputsPath = Join-Path $directory.FullName 'deployment\inputs.json'
    if (Test-Path -LiteralPath $inputsPath -PathType Leaf) {
        [void](Read-JsonFile $inputsPath 'deployment-inputs.schema.json')
    }
}

$catalogPath = Join-Path $RepositoryRoot 'catalog.json'
$manifestPath = Join-Path $RepositoryRoot 'generated-manifest.json'
$catalog = if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
    Read-JsonFile $catalogPath 'catalog.schema.json'
}
else {
    if ($artifactDirectories.Count -gt 0) { Add-Failure 'catalog.json is required when artifacts exist.' }
    $null
}
$manifest = if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    Read-JsonFile $manifestPath 'generated-manifest.schema.json'
}
else {
    if ($artifactDirectories.Count -gt 0) { Add-Failure 'generated-manifest.json is required when artifacts exist.' }
    $null
}

if ($ValidationMode -eq 'PullRequest') {
    if ($pr.Deleted -ccontains 'catalog.json') {
        Add-Failure 'Deleting catalog.json is prohibited; publish an updated catalog with explicit removals.'
    }
    if ($pr.Deleted -ccontains 'generated-manifest.json') {
        Add-Failure 'Deleting generated-manifest.json is prohibited; retain it with explicit removals.'
    }
    $deletedGenerated = @($pr.Deleted | Where-Object { Test-GeneratedPath $_ })
    if ($deletedGenerated.Count -gt 0 -and $null -eq $manifest) {
        Add-Failure 'Generated deletions require a candidate generated-manifest.json with explicit removal events.'
    }
    if ($baseState.HasCatalog -and $null -eq $catalog) {
        Add-Failure 'The protected base catalog cannot disappear from a publication pull request.'
    }
    if ($baseState.HasManifest -and $null -eq $manifest) {
        Add-Failure 'The protected base generated manifest cannot disappear from a publication pull request.'
    }
}

if ($null -ne $catalog) {
    Test-PropertyOrder $catalog @('schemaVersion', 'generatedAt', 'artifacts') 'catalog.json'
    $catalogOrder = @($catalog.artifacts | ForEach-Object { [string]$_.id })
    $sortedCatalogOrder = @(Get-OrdinalSorted $catalogOrder)
    if (($catalogOrder -join "`n") -cne ($sortedCatalogOrder -join "`n")) {
        Add-Failure 'catalog.json artifacts must be deterministically ordered by id.'
    }
    $catalogIds = @{}
    foreach ($entry in $catalog.artifacts) {
        Test-PropertyOrder $entry @(
            'id', 'artifactVersion', 'solutionArea', 'component', 'title',
            'path', 'metadataSha256', 'status'
        ) "catalog.json entry '$($entry.id)'"
        if ($catalogIds.ContainsKey([string]$entry.id)) {
            Add-Failure "Catalog repeats artifact id '$($entry.id)'."
            continue
        }
        $catalogIds[[string]$entry.id] = $true
        if (-not $metadataById.ContainsKey([string]$entry.id)) {
            Add-Failure "Catalog declares unknown artifact '$($entry.id)'."
            continue
        }
        $source = $metadataById[[string]$entry.id]
        $metadata = $source.Metadata
        if ($entry.path -ne $source.Directory) { Add-Failure "Catalog path for '$($entry.id)' does not match metadata path." }
        if ($entry.artifactVersion -ne $metadata.artifactVersion) { Add-Failure "Catalog version for '$($entry.id)' does not match metadata." }
        if ($entry.solutionArea -ne $metadata.solutionArea) { Add-Failure "Catalog solution area for '$($entry.id)' does not match metadata." }
        if ($entry.component -ne $metadata.component) { Add-Failure "Catalog component for '$($entry.id)' does not match metadata." }
        if ($entry.title -ne $metadata.title) { Add-Failure "Catalog title for '$($entry.id)' does not match metadata." }
        if ($entry.metadataSha256 -ne (Get-Sha256 $source.MetadataPath)) { Add-Failure "Catalog metadata hash for '$($entry.id)' is incorrect." }
    }
    foreach ($id in $metadataById.Keys) {
        if (-not $catalogIds.ContainsKey($id)) { Add-Failure "Artifact '$id' is missing from catalog.json." }
    }
}

if ($null -ne $manifest) {
    Test-PropertyOrder $manifest @(
        'schemaVersion', 'publicationVersion', 'generatedAt', 'publisher',
        'files', 'removals'
    ) 'generated-manifest.json'
    $declared = @{}
    $manifestPaths = @($manifest.files | ForEach-Object { [string]$_.path })
    Test-NormalizedCollisions $manifestPaths
    $sortedManifestPaths = @(Get-OrdinalSorted $manifestPaths)
    if (($manifestPaths -join "`n") -cne ($sortedManifestPaths -join "`n")) {
        Add-Failure 'generated-manifest.json files must be deterministically ordered by path.'
    }
    $removalOrder = @($manifest.removals | ForEach-Object { [string]$_.id })
    $sortedRemovalOrder = @(Get-OrdinalSorted $removalOrder)
    if (($removalOrder -join "`n") -cne ($sortedRemovalOrder -join "`n")) {
        Add-Failure 'generated-manifest.json removals must be deterministically ordered by id.'
    }
    $removalIds = @{}
    $deletedArtifactIds = @(
        $pr.Deleted |
            Where-Object { $_ -match '^templates/(?:intune|defender|purview|entra)/[^/]+/([^/]+)(?:/|$)' } |
            ForEach-Object {
                [void]($_ -match '^templates/(?:intune|defender|purview|entra)/[^/]+/([^/]+)(?:/|$)')
                $Matches[1]
            } |
            Sort-Object -Unique
    )
    foreach ($removal in $manifest.removals) {
        $removalId = [string]$removal.id
        if ($removalIds.ContainsKey($removalId)) {
            Add-Failure "Manifest repeats removal event for '$removalId'."
            continue
        }
        $removalIds[$removalId] = $true
        if ($ValidationMode -eq 'PullRequest') {
            if (-not $baseState.MetadataById.ContainsKey($removalId)) {
                Add-Failure "Removal '$removalId' does not identify an artifact in the protected base."
            }
            elseif ([string]$removal.priorVersion -ne $baseState.MetadataById[$removalId].Version) {
                Add-Failure "Removal '$removalId' priorVersion '$($removal.priorVersion)' does not match protected-base version '$($baseState.MetadataById[$removalId].Version)'."
            }
            if ($deletedArtifactIds -cnotcontains $removalId) {
                Add-Failure "Removal '$removalId' is unused because that artifact is not deleted in this pull request."
            }
        }
    }
    foreach ($entry in $manifest.files) {
        Test-PropertyOrder $entry @('path', 'byteLength', 'sha256') "manifest entry '$($entry.path)'"
        $path = [string]$entry.path
        if (-not (Test-SafeRelativePath $path) -or -not (Test-GeneratedPath $path) -or $path -eq 'generated-manifest.json') {
            Add-Failure "Manifest contains invalid generated path '$path'."
            continue
        }
        if ($declared.ContainsKey($path)) {
            Add-Failure "Manifest repeats generated path '$path'."
            continue
        }
        $declared[$path] = $true
        $fullPath = Join-Path $RepositoryRoot $path.Replace('/', '\')
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            Add-Failure "Manifest declares missing file '$path'."
        }
        elseif ($entry.sha256 -ne (Get-Sha256 $fullPath)) {
            Add-Failure "Manifest SHA-256 mismatch for '$path'."
        }
        elseif ([int64]$entry.byteLength -ne (Get-Item -LiteralPath $fullPath).Length) {
            Add-Failure "Manifest byte length mismatch for '$path'."
        }
    }
    foreach ($file in $generatedFiles) {
        $relative = Convert-ToRelativePath $file.FullName
        if ($relative -ne 'generated-manifest.json' -and -not $declared.ContainsKey($relative)) {
            Add-Failure "Generated file '$relative' is not declared in generated-manifest.json."
        }
    }

    foreach ($deletedId in $deletedArtifactIds) {
        if (-not $removalIds.ContainsKey($deletedId)) {
            Add-Failure "Deleted artifact '$deletedId' requires an explicit generated-manifest removal event."
        }
    }
}

$summary = [ordered]@{
    repository = $RepositoryRoot
    mode = $ValidationMode
    generatedPullRequest = $pr.IsGenerated
    artifacts = $metadataById.Count
    generatedFiles = $generatedFiles.Count
    failures = $script:Failures
    warnings = $script:Warnings
}
$summaryJson = $summary | ConvertTo-Json -Depth 10
if ($ReportPath) {
    $resolvedReport = if ([System.IO.Path]::IsPathRooted($ReportPath)) {
        $ReportPath
    }
    else {
        Join-Path $RepositoryRoot $ReportPath
    }
    $parent = Split-Path -Parent $resolvedReport
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($resolvedReport, "$summaryJson`n", $utf8Strict)
}

if ($script:Failures.Count -gt 0) {
    Write-Host "Publication validation failed with $($script:Failures.Count) error(s)."
    exit 1
}

Write-Host "Publication validation passed: $($metadataById.Count) artifact(s), $($generatedFiles.Count) generated file(s)."
if ($script:Warnings.Count -gt 0) {
    Write-Host "Warnings: $($script:Warnings.Count)"
}
