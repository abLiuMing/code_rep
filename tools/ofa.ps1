[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(Position = 1)]
    [string]$Argument
)

$ErrorActionPreference = "Stop"
$Root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$DefaultArtifactBase = "https://raw.githubusercontent.com/abLiuMing/res_rep/demo-artifacts"

function Invoke-ProjectGit {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    & git -C $Root @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git command failed with exit code $LASTEXITCODE"
    }
}

function Sync-Resources {
    Invoke-ProjectGit submodule update --init --recursive
}

function Get-ManifestPath {
    $LockFile = Join-Path $Root "resource.lock"
    $ManifestName = $null
    foreach ($Line in Get-Content -LiteralPath $LockFile) {
        if ($Line.Trim().StartsWith("manifest=")) {
            $ManifestName = $Line.Trim().Substring("manifest=".Length)
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($ManifestName)) {
        throw "manifest is missing from $LockFile"
    }
    return Join-Path $Root "deps/resource_config/manifests/$ManifestName"
}

function Get-ManifestEntries {
    param([string]$ManifestPath)
    foreach ($Line in Get-Content -LiteralPath $ManifestPath) {
        $Trimmed = $Line.Trim()
        if (-not $Trimmed -or $Trimmed.StartsWith("#")) { continue }
        $Fields = $Trimmed -split "\s+"
        if ($Fields.Count -ne 4) {
            throw "invalid manifest line: $Line"
        }
        [PSCustomObject]@{
            Name = $Fields[0]
            Version = $Fields[1]
            Artifact = $Fields[2]
            Checksum = $Fields[3].ToLowerInvariant()
        }
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Prepare-Resources {
    Sync-Resources
    $ManifestPath = Get-ManifestPath
    $CacheDir = Join-Path $Root ".resource-cache"
    $ArtifactBase = if ($env:RESOURCE_BASE_URL) { $env:RESOURCE_BASE_URL.TrimEnd("/", "\") } else { $DefaultArtifactBase }
    New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

    foreach ($Entry in Get-ManifestEntries $ManifestPath) {
        $RelativeArtifact = $Entry.Artifact.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
        $Target = Join-Path $CacheDir $RelativeArtifact
        $TargetDir = Split-Path -Parent $Target
        New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

        $CacheValid = (Test-Path -LiteralPath $Target -PathType Leaf) -and ((Get-Sha256 $Target) -eq $Entry.Checksum)
        if ($CacheValid) {
            Write-Host "cache hit: $($Entry.Name) $($Entry.Version)"
            continue
        }

        Write-Host "fetching $($Entry.Name) $($Entry.Version)"
        $Temporary = "$Target.tmp"
        if (Test-Path -LiteralPath $Temporary) { Remove-Item -Force -LiteralPath $Temporary }

        if ($ArtifactBase -match "^https?://") {
            $Url = $ArtifactBase.TrimEnd("/") + "/" + $Entry.Artifact.Replace("\", "/")
            Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Temporary
        } else {
            $Source = Join-Path $ArtifactBase $RelativeArtifact
            Copy-Item -LiteralPath $Source -Destination $Temporary
        }

        $Actual = Get-Sha256 $Temporary
        if ($Actual -ne $Entry.Checksum) {
            Remove-Item -Force -LiteralPath $Temporary
            throw "checksum mismatch for $($Entry.Artifact): expected $($Entry.Checksum), got $Actual"
        }
        Move-Item -Force -LiteralPath $Temporary -Destination $Target
    }
}

function Build-Resources {
    Prepare-Resources
    $ManifestPath = Get-ManifestPath
    $BuildScript = Join-Path $Root "deps/resource_config/scripts/build_resources.ps1"
    $CacheDir = Join-Path $Root ".resource-cache"
    $OutputDir = Join-Path $Root "build/generated_resources"
    & $BuildScript -Manifest $ManifestPath -DownloadDir $CacheDir -OutputDir $OutputDir
}

switch ($Command.ToLowerInvariant()) {
    "sync" { Sync-Resources }
    "prepare" { Prepare-Resources }
    "build" { Build-Resources }
    "run" {
        Build-Resources
        & (Join-Path $Root "src/main.ps1")
    }
    "switch" {
        if ([string]::IsNullOrWhiteSpace($Argument)) { throw "usage: ofa switch <branch>" }
        Invoke-ProjectGit switch $Argument
        Sync-Resources
    }
    "status" {
        Invoke-ProjectGit status --short
        & git -C (Join-Path $Root "deps/resource_config") rev-parse --short HEAD
        if ($LASTEXITCODE -ne 0) { throw "unable to read resource repository status" }
    }
    default {
        Write-Host "usage: ofa {sync|prepare|build|run|switch <branch>|status}"
    }
}
