# PowerShell Profile Configuration
# This file is loaded when PowerShell starts
# Location: $PROFILE (typically ~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1)
# But managed by chezmoi in ~/.config/powershell/

# Measure profile load time for performance diagnostics
$script:_profileLoadStart = [System.Diagnostics.Stopwatch]::StartNew()

# Set when the fastfetch banner rendered, so the welcome lines below can stay
# out of the way.
$script:_fastfetchShown = $false

# Set UTF-8 encoding (force code page 65001 for Windows PowerShell 5.1)
if ($PSVersionTable.PSVersion.Major -lt 7) {
    chcp 65001 | Out-Null
}
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Environment variables
$env:SOPS_EDITOR = "code --wait"

# Load chezmoi configuration variables
$chezmoiConfig = Join-Path $PSScriptRoot "chezmoi.ps1"
if (Test-Path $chezmoiConfig) {
    . $chezmoiConfig
}

# Add OneDrive Portable Programs to this PowerShell session without reading
# the registry on every startup. Persistence is handled by a chezmoi script.
if ($env:OneDrive) {
    $portableProgramsPath = Join-Path $env:OneDrive "Portable Programs"
    $portableProgramsKey = $portableProgramsPath.Trim().Trim('"').TrimEnd('\').ToUpperInvariant()
    $portableProgramsInPath = $false
    $currentSessionPath = if ($null -eq $env:Path) { "" } else { $env:Path }

    foreach ($pathEntry in ($currentSessionPath -split ';')) {
        if ($pathEntry.Trim().Trim('"').TrimEnd('\').ToUpperInvariant() -eq $portableProgramsKey) {
            $portableProgramsInPath = $true
            break
        }
    }

    if (-not $portableProgramsInPath) {
        $env:Path = if ([string]::IsNullOrWhiteSpace($currentSessionPath)) {
            $portableProgramsPath
        }
        elseif ($currentSessionPath.EndsWith(';')) {
            "$currentSessionPath$portableProgramsPath"
        }
        else {
            "$currentSessionPath;$portableProgramsPath"
        }
    }
}

# Load DotfilesHelpers module (lazy-loadable via PSModulePath, explicit import for profile)
$dotfilesModulePath = Join-Path $PSScriptRoot "modules\DotfilesHelpers"
if (Test-Path $dotfilesModulePath) {
    Import-Module $dotfilesModulePath -DisableNameChecking
}

# Set working directory to projects folder if not already there
# Get-ProjectsPath prefers a Dev Drive over $env:USERPROFILE when one exists
# Skip this if running in VS Code to preserve the opened folder location
if ($ENV:TERM_PROGRAM -ne "vscode") {
    $currentPath = (Get-Location).Path
    $projectsPath = if (Get-Command Get-ProjectsPath -ErrorAction SilentlyContinue) {
        Get-ProjectsPath
    }
    else {
        Join-Path $env:USERPROFILE "projects"
    }

    # Check if current path contains 'projects' (case-insensitive)
    if ($currentPath -notlike "*projects*") {
        # Not in projects directory, change to it if it exists
        if (Test-Path $projectsPath) {
            Set-Location $projectsPath
        }
    }
}

# Load aliases
. $PSScriptRoot\aliases.ps1

# Cache git command availability once at startup (avoids a full PATH scan on every prompt render)
$script:_gitCmd = Get-Command git -ErrorAction SilentlyContinue

# Custom prompt (simple and clean)
function prompt {
    $loc = Get-Location
    $gitBranch = ""

    # Get git branch if in a git repo (availability cached at profile startup)
    if ($script:_gitCmd) {
        $gitBranch = & git rev-parse --abbrev-ref HEAD 2>$null
        if ($gitBranch) {
            $gitBranch = " ($gitBranch)"
        }
    }

    Write-Host "$loc" -NoNewline -ForegroundColor Cyan
    Write-Host "$gitBranch" -NoNewline -ForegroundColor Yellow
    return "> "
}

# Load completions
$completionsPath = Join-Path $PSScriptRoot "completions"
if (Test-Path $completionsPath) {
    Get-ChildItem -Path $completionsPath -Filter "*.ps1" | ForEach-Object {
        . $_.FullName
    }
}

# Show fastfetch only in interactive sessions (not when scripts import modules),
# mirroring the fish_greeting behaviour on Linux/macOS. fastfetch is installed on
# Windows via winget (Fastfetch-cli.Fastfetch) and simply does not run when it is
# absent, so a light install stays quiet.
#
# Guarded with a timeout because a fetch tool occasionally hangs on a hardware
# probe (e.g. the GPU query on Snapdragon X), which would otherwise freeze the
# entire profile load and ignore Ctrl+C. See issue: pwsh session hangs on
# profile load.
if ([Environment]::UserInteractive -and -not $env:CHEZMOI_SOURCE_DIR) {
    $fastfetchCmd = Get-Command fastfetch -ErrorAction SilentlyContinue
    if ($fastfetchCmd) {
        # Render the extra status lines (winget updates) and, when the cache has
        # aged out, kick off a detached refresh for the next shell. Both are
        # cheap; the expensive winget query never runs on this path. See
        # DotfilesHelpers/Public/FastfetchStatus.ps1.
        if (Get-Command Update-FastfetchStatusCache -ErrorAction SilentlyContinue) {
            try {
                Update-FastfetchStatusCache
            } catch {
                # A missing status line is never a reason to break the shell.
                Write-Verbose "fastfetch status cache update failed: $($_.Exception.Message)"
            }
        }

        # Allow users to tune the timeout (milliseconds) via an env var.
        $fastfetchTimeoutMs = 5000
        $parsedTimeout = 0
        if ($env:FASTFETCH_TIMEOUT_MS -and
            [int]::TryParse($env:FASTFETCH_TIMEOUT_MS, [ref]$parsedTimeout) -and
            $parsedTimeout -gt 0) {
            $fastfetchTimeoutMs = $parsedTimeout
        }

        if ($fastfetchCmd.CommandType -in @([System.Management.Automation.CommandTypes]::Application,
                                            [System.Management.Automation.CommandTypes]::ExternalScript)) {
            # External executable/script: launch it attached to the current
            # console so colors/unicode render normally, and kill it if it
            # doesn't finish within the timeout.
            try {
                $fastfetchProc = Start-Process -FilePath $fastfetchCmd.Source `
                    -NoNewWindow -PassThru -ErrorAction Stop
                if (-not $fastfetchProc.WaitForExit($fastfetchTimeoutMs)) {
                    try { $fastfetchProc.Kill() } catch { }
                    Write-Host "`n(fastfetch timed out after $([math]::Round($fastfetchTimeoutMs / 1000, 1))s; skipping)" -ForegroundColor DarkYellow
                } elseif ($fastfetchProc.ExitCode -eq 0) {
                    # Only a clean run actually painted a banner. A non-zero exit
                    # (bad config, for instance) leaves the screen empty, so the
                    # welcome lines below stay as the one sign of life.
                    $script:_fastfetchShown = $true
                }
            } catch {
                Write-Host "(fastfetch failed to start: $($_.Exception.Message))" -ForegroundColor DarkYellow
            }
        } else {
            # Function/alias/cmdlet: no reliable way to cancel cooperatively,
            # so just invoke it directly.
            fastfetch
            $script:_fastfetchShown = $true
        }
    }
}

# Welcome message (only in interactive sessions). fastfetch already reports the
# shell and everything else worth knowing, so when its banner rendered these two
# lines are pure noise and are skipped. A light install without fastfetch keeps
# them, so an interactive shell still confirms the profile loaded.
if ([Environment]::UserInteractive -and -not $env:CHEZMOI_SOURCE_DIR -and -not $script:_fastfetchShown) {
    $script:_profileLoadStart.Stop()
    $loadTimeMs = $script:_profileLoadStart.ElapsedMilliseconds
    Write-Host "[OK] PowerShell Profile Loaded ($loadTimeMs ms)" -ForegroundColor Green
    Write-Host ">> Type 'aliases' to see available aliases" -ForegroundColor Yellow
}
