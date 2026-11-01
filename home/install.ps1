# PowerShell installation script for Windows
# Downloads and installs chezmoi, then applies dotfiles

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ChezmoiVersion = "latest"
)

$ErrorActionPreference = "Stop"

# Function to check if running interactively
function Test-Interactive {
    # Return false (non-interactive) if:
    # - CI environment variable is set
    # - Running in automation (e.g., Azure DevOps, GitHub Actions)
    # - Host doesn't support user interaction
    if ($env:CI -eq "true" -or
        $env:TF_BUILD -eq "true" -or
        $env:GITHUB_ACTIONS -eq "true" -or
        -not [Environment]::UserInteractive) {
        return $false
    }
    return $true
}

function Get-RequiredChezmoiVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir
    )

    $versionFile = Join-Path $SourceDir ".chezmoiversion"
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw).Trim()
    }

    return $null
}

function Get-ChezmoiVersion {
    param(
        [Parameter(Mandatory = $true)]
        $CommandInfo
    )

    try {
        $versionOutput = & $CommandInfo.Source --version 2>$null | Select-Object -First 1
    }
    catch {
        return $null
    }

    if ($versionOutput -match '(\d+\.\d+\.\d+(?:[-+][^\s]+)?)') {
        return $Matches[1]
    }

    return $null
}

function Test-VersionAtLeast {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$MinimumVersion
    )

    try {
        $normalizedVersion = $Version -replace '[-+].*$', ''
        $normalizedMinimum = $MinimumVersion -replace '[-+].*$', ''
        return ([version]$normalizedVersion) -ge ([version]$normalizedMinimum)
    }
    catch {
        return $false
    }
}

function Update-PathFromMachineAndUser {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")

    if ($machinePath -and $userPath) {
        $env:Path = $machinePath + ";" + $userPath
    }
    elseif ($machinePath) {
        $env:Path = $machinePath
    }
}

function Format-CommandOutput {
    param(
        [Parameter()]
        [object[]]$Output
    )

    return ($Output | ForEach-Object { "$_" }) -join [Environment]::NewLine
}

function Update-WingetSource {
    Write-Host "Updating winget sources..." -ForegroundColor Cyan
    $sourceUpdateOutput = winget source update 2>&1
    if ($LASTEXITCODE -eq 0) {
        return
    }

    Write-Warning "winget source update failed; resetting winget sources. Captured stdout/stderr: $(Format-CommandOutput -Output $sourceUpdateOutput)"
    $sourceResetOutput = winget source reset --force 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "winget source reset failed with exit code $LASTEXITCODE. Captured stdout/stderr: $(Format-CommandOutput -Output $sourceResetOutput)"
    }

    $sourceUpdateOutput = winget source update 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "winget source update failed with exit code $LASTEXITCODE. Captured stdout/stderr: $(Format-CommandOutput -Output $sourceUpdateOutput)"
    }
}

function Get-WingetChezmoiVersion {
    $searchOutput = winget search --id twpayne.chezmoi --exact --source winget --accept-source-agreements 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "winget search chezmoi failed with exit code $LASTEXITCODE. Captured stdout/stderr: $(Format-CommandOutput -Output $searchOutput)"
        return $null
    }

    foreach ($line in $searchOutput) {
        if ($line -match '^\s*\S+\s+twpayne\.chezmoi\s+(\d+\.\d+\.\d+(?:[-+][^\s]+)?)\b') {
            return $Matches[1]
        }
    }

    Write-Warning "winget search did not return a parseable chezmoi version. Captured stdout/stderr: $(Format-CommandOutput -Output $searchOutput)"
    return $null
}

function Install-ChezmoiWithWinget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter()]
        [switch]$Upgrade
    )

    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetPath) {
        Write-Error "winget is not available. Please install Windows Package Manager (winget) first."
        exit 1
    }

    Update-WingetSource

    # Keep the discovered package version so fresh installs can pin a version
    # that winget actually provides while still satisfying .chezmoiversion.
    $wingetVersion = $null
    if ($Version -ne "latest") {
        $wingetVersion = Get-WingetChezmoiVersion
        if (-not $wingetVersion -or -not (Test-VersionAtLeast -Version $wingetVersion -MinimumVersion $Version)) {
            $displayVersion = if ($wingetVersion) { $wingetVersion } else { "unknown" }
            Write-Error "winget provides chezmoi $displayVersion, but this source requires $Version or later. No manual installer fallback is used; run 'winget source update' manually or check winget community source status before retrying."
            exit 1
        }
    }

    $action = if ($Upgrade) { "upgrade" } else { "install" }
    $wingetArgs = @(
        $action,
        "--id", "twpayne.chezmoi",
        "--source", "winget",
        "--silent",
        "--accept-source-agreements",
        "--accept-package-agreements"
    )

    # Let winget upgrades move to its latest available package; pin fresh installs
    # to the discovered package version that satisfies .chezmoiversion.
    if ($wingetVersion -and -not $Upgrade) {
        $wingetArgs += @("--version", $wingetVersion)
    }

    Write-Host "Running: winget $($wingetArgs -join ' ')" -ForegroundColor Cyan
    winget @wingetArgs

    if ($LASTEXITCODE -ne 0) {
        throw "winget $action failed with exit code $LASTEXITCODE"
    }

    Write-Host "Chezmoi installed successfully with winget" -ForegroundColor Green
    Write-Host "Refreshing path environment variable..." -ForegroundColor Cyan
    Update-PathFromMachineAndUser
}

function Assert-RequiredChezmoiVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RequiredVersion
    )

    $chezmoiCommand = Get-Command chezmoi -ErrorAction SilentlyContinue
    if (-not $chezmoiCommand) {
        Write-Error "chezmoi was not found after package-manager installation."
        exit 1
    }

    $installedVersion = Get-ChezmoiVersion -CommandInfo $chezmoiCommand
    if (-not $installedVersion -or -not (Test-VersionAtLeast -Version $installedVersion -MinimumVersion $RequiredVersion)) {
        $displayVersion = if ($installedVersion) { $installedVersion } else { "unknown" }
        $remediation = "Run 'winget source update' and check availability with 'winget search --id twpayne.chezmoi --exact --source winget --accept-source-agreements', then rerun this installer when the required version is available."
        Write-Error "chezmoi $displayVersion was installed, but this source requires $RequiredVersion or later. $remediation"
        exit 1
    }
}

$isInteractive = Test-Interactive

# Get the source directory (script's directory)
$sourceDir = $PSScriptRoot
$requiredChezmoiVersion = if ($ChezmoiVersion -eq "latest") {
    Get-RequiredChezmoiVersion -SourceDir $sourceDir
} else {
    $ChezmoiVersion
}

# Check if chezmoi is already installed
$chezmoiExists = Get-Command chezmoi -ErrorAction SilentlyContinue

if ($chezmoiExists -and $requiredChezmoiVersion) {
    $installedChezmoiVersion = Get-ChezmoiVersion -CommandInfo $chezmoiExists
    if (-not $installedChezmoiVersion -or -not (Test-VersionAtLeast -Version $installedChezmoiVersion -MinimumVersion $requiredChezmoiVersion)) {
        $displayChezmoiVersion = if ($installedChezmoiVersion) { $installedChezmoiVersion } else { "unknown" }
        Write-Warning "chezmoi $displayChezmoiVersion is older than required $requiredChezmoiVersion"
        Install-ChezmoiWithWinget -Version $requiredChezmoiVersion -Upgrade
        Assert-RequiredChezmoiVersion -RequiredVersion $requiredChezmoiVersion
        $chezmoiExists = Get-Command chezmoi -ErrorAction SilentlyContinue
    }
}

if (-not $chezmoiExists) {
    if ($requiredChezmoiVersion) {
        Install-ChezmoiWithWinget -Version $requiredChezmoiVersion
        Assert-RequiredChezmoiVersion -RequiredVersion $requiredChezmoiVersion
        $chezmoiExists = Get-Command chezmoi -ErrorAction SilentlyContinue
    }
    else {
        try {
            Install-ChezmoiWithWinget -Version "latest"
        }
        catch {
            Write-Error "Failed to install chezmoi: $_"
            exit 1
        }
    }
}
else {
    Write-Host "Chezmoi already installed" -ForegroundColor Green
}

# Build chezmoi arguments
$chezmoiArgs = @("init", "--apply")

if (-not $isInteractive) {
    $chezmoiArgs += "--no-tty"
}

if ($sourceDir) {
    $chezmoiArgs += "--source=$sourceDir"
}

# Run chezmoi
Write-Host "`nRunning: chezmoi $($chezmoiArgs -join ' ')" -ForegroundColor Cyan
chezmoi $chezmoiArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Chezmoi init failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "`n[OK] Dotfiles installation complete!" -ForegroundColor Green
Write-Host ">> Run 'chezmoi update' to pull and apply the latest changes" -ForegroundColor Yellow
