<#
.SYNOPSIS
  Zero-dependency Windows installer/uninstaller for agy-clarity (Google Antigravity plugin).
.DESCRIPTION
  Syncs agy-clarity plugin files into $HOME\.gemini\config\plugins\agy-clarity (excluding .git)
  without requiring Node.js or Python and without modifying config.json.
  Supports both remote one-liner (`irm ... | iex`) and local repository runs.
.EXAMPLE
  irm https://raw.githubusercontent.com/zou172866/Antigravity-agy-clarity/main/install.ps1 | iex
.EXAMPLE
  .\install.ps1
.EXAMPLE
  .\install.ps1 -Uninstall
.EXAMPLE
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/zou172866/Antigravity-agy-clarity/main/install.ps1))) -Uninstall
#>
param(
  [switch]$Uninstall,
  [string]$TargetDir = ""
)

$ErrorActionPreference = "Stop"

$RepoSlug = "zou172866/Antigravity-agy-clarity"
$RepoGitUrl = "https://github.com/$RepoSlug.git"
$RepoZipUrl = "https://github.com/$RepoSlug/archive/refs/heads/main.zip"
$ScriptPath = $MyInvocation.MyCommand.Path

function Fail-Install {
  param([string]$Message)
  if ($ScriptPath) {
    Write-Error $Message
    exit 1
  }
  throw $Message
}

function Normalize-FullPath {
  param([string]$PathValue)
  if (-not [System.IO.Path]::IsPathRooted($PathValue)) {
    $PathValue = Join-Path (Get-Location).ProviderPath $PathValue
  }
  $full = [System.IO.Path]::GetFullPath($PathValue)
  $root = [System.IO.Path]::GetPathRoot($full)
  if ($full -ine $root) {
    $full = $full.TrimEnd('\', '/')
  }
  return $full
}

function Test-PluginSource {
  param([string]$DirPath)
  if (-not $DirPath -or -not (Test-Path -LiteralPath $DirPath -PathType Container)) {
    return $false
  }
  $required = @(
    "plugin.json",
    "rules\AGENTS.md",
    "skills\wait-what\SKILL.md"
  )
  foreach ($rel in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $DirPath $rel) -PathType Leaf)) {
      return $false
    }
  }
  return $true
}

$HomeDir = if ($HOME) { $HOME } else { [Environment]::GetFolderPath("UserProfile") }
if (-not $HomeDir) {
  Fail-Install "Unable to determine user home directory."
}

$CustomTarget = -not [string]::IsNullOrWhiteSpace($TargetDir)
$DefaultTarget = Join-Path $HomeDir ".gemini\config\plugins\agy-clarity"
$RawTarget = if ($CustomTarget) { $TargetDir } else { $DefaultTarget }
$ResolvedTarget = Normalize-FullPath $RawTarget

$ProtectedPaths = @(
  [System.IO.Path]::GetPathRoot($ResolvedTarget),
  (Normalize-FullPath $HomeDir),
  (Normalize-FullPath (Join-Path $HomeDir ".gemini")),
  (Normalize-FullPath (Join-Path $HomeDir ".gemini\config")),
  (Normalize-FullPath (Join-Path $HomeDir ".gemini\config\plugins"))
)
foreach ($protected in $ProtectedPaths) {
  if ($ResolvedTarget -ieq $protected) {
    Fail-Install "Refusing to operate on protected path: $ResolvedTarget"
  }
}

if ($Uninstall) {
  if (-not (Test-Path -LiteralPath $ResolvedTarget)) {
    Write-Host "[agy-clarity] Not installed at $ResolvedTarget (nothing to remove)."
    return
  }

  $leafName = Split-Path -Leaf $ResolvedTarget
  $hasManifest = Test-Path -LiteralPath (Join-Path $ResolvedTarget "plugin.json") -PathType Leaf
  if ($CustomTarget -and ($leafName -ine "agy-clarity") -and (-not $hasManifest)) {
    Fail-Install "Refusing to remove '$ResolvedTarget': directory is not named 'agy-clarity' and contains no plugin.json."
  }

  Remove-Item -LiteralPath $ResolvedTarget -Recurse -Force
  Write-Host "[agy-clarity] Uninstalled plugin from: $ResolvedTarget"
  Write-Host "[agy-clarity] Restart or reload your Antigravity window to apply changes."
  return
}

$ScriptDir = if ($ScriptPath) { Split-Path -Parent $ScriptPath } else { "" }
$SourceDir = ""
$TempWorkDir = ""
$StageDir = ""
$BackupDir = ""
$SwapCompleted = $false

try {
  if (Test-PluginSource $ScriptDir) {
    $SourceDir = $ScriptDir
    Write-Host "[agy-clarity] Installing from local repository: $SourceDir"
  } else {
    $TempWorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ("agy-clarity-install-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $TempWorkDir | Out-Null
    $RepoDir = Join-Path $TempWorkDir "repo"
    $Fetched = $false

    if (Get-Command git -ErrorAction SilentlyContinue) {
      Write-Host "[agy-clarity] Fetching latest release from GitHub via git..."
      $prevEap = $ErrorActionPreference
      try {
        $ErrorActionPreference = "Continue"
        & git clone --depth 1 --quiet $RepoGitUrl $RepoDir 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0 -and (Test-PluginSource $RepoDir)) {
          $SourceDir = $RepoDir
          $Fetched = $true
        }
      } catch {
        $Fetched = $false
      } finally {
        $ErrorActionPreference = $prevEap
      }
      if (-not $Fetched -and (Test-Path -LiteralPath $RepoDir)) {
        Remove-Item -LiteralPath $RepoDir -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    if (-not $Fetched) {
      Write-Host "[agy-clarity] Downloading archive from GitHub..."
      try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
      } catch {
        # Ignore on runtimes where SecurityProtocol is managed automatically
      }
      $ZipFile = Join-Path $TempWorkDir "agy-clarity.zip"
      Invoke-WebRequest -Uri $RepoZipUrl -OutFile $ZipFile -UseBasicParsing
      Expand-Archive -Path $ZipFile -DestinationPath $TempWorkDir -Force
      $Extracted = Get-ChildItem -LiteralPath $TempWorkDir -Directory | Where-Object { Test-PluginSource $_.FullName } | Select-Object -First 1
      if (-not $Extracted) {
        Fail-Install "Failed to locate valid agy-clarity files inside downloaded archive."
      }
      $SourceDir = $Extracted.FullName
    }
  }

  if (-not (Test-PluginSource $SourceDir)) {
    Fail-Install "Invalid agy-clarity source directory: $SourceDir"
  }

  $ResolvedSource = Normalize-FullPath $SourceDir
  if ($ResolvedSource -ieq $ResolvedTarget) {
    Write-Host "[agy-clarity] Plugin is already installed in place at: $ResolvedTarget"
    Write-Host "[agy-clarity] Restart or reload your Antigravity window if not yet loaded."
    return
  }

  $ParentDir = Split-Path -Parent $ResolvedTarget
  New-Item -ItemType Directory -Force -Path $ParentDir | Out-Null

  $StageDir = Join-Path $ParentDir (".agy-clarity-stage-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

  $Items = Get-ChildItem -LiteralPath $ResolvedSource -Force | Where-Object { $_.Name -ne ".git" }
  foreach ($item in $Items) {
    Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $StageDir $item.Name) -Recurse -Force
  }

  # Defensive strip in case any nested .git metadata existed
  $NestedGit = Join-Path $StageDir ".git"
  if (Test-Path -LiteralPath $NestedGit) {
    Remove-Item -LiteralPath $NestedGit -Recurse -Force
  }

  if (-not (Test-PluginSource $StageDir)) {
    Fail-Install "Staged plugin bundle failed integrity check."
  }

  if (Test-Path -LiteralPath $ResolvedTarget) {
    $BackupDir = Join-Path $ParentDir (".agy-clarity-backup-" + [guid]::NewGuid().ToString("N"))
    Move-Item -LiteralPath $ResolvedTarget -Destination $BackupDir
  }

  try {
    Move-Item -LiteralPath $StageDir -Destination $ResolvedTarget
    $SwapCompleted = $true
  } catch {
    if ($BackupDir -and (Test-Path -LiteralPath $BackupDir) -and (-not (Test-Path -LiteralPath $ResolvedTarget))) {
      Move-Item -LiteralPath $BackupDir -Destination $ResolvedTarget -ErrorAction SilentlyContinue
    }
    throw
  }

  if ($BackupDir -and (Test-Path -LiteralPath $BackupDir)) {
    Remove-Item -LiteralPath $BackupDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  Write-Host "[agy-clarity] Installed successfully to: $ResolvedTarget"
  Write-Host "[agy-clarity] Included: rules/AGENTS.md (always-on) and skills/wait-what/SKILL.md (on-demand)."
  Write-Host "[agy-clarity] config.json was not modified. Restart or reload your Antigravity window to activate."
} finally {
  if ($TempWorkDir -and (Test-Path -LiteralPath $TempWorkDir)) {
    Remove-Item -LiteralPath $TempWorkDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  if ($StageDir -and (Test-Path -LiteralPath $StageDir)) {
    Remove-Item -LiteralPath $StageDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  if ($SwapCompleted -and $BackupDir -and (Test-Path -LiteralPath $BackupDir)) {
    Remove-Item -LiteralPath $BackupDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}
