# Chezmoi utilities

function Reset-ChezmoiScripts {
    # Clears Chezmoi script execution state to force re-running of run_once_* and run_onchange_* scripts
    chezmoi state delete-bucket --bucket=scriptState
    Write-Host "Chezmoi script state cleared. run_once_* scripts will re-execute on next 'chezmoi apply'." -ForegroundColor Green
}

function Reset-ChezmoiEntries {
    # Clears Chezmoi entry state to force reprocessing of all managed files
    chezmoi state delete-bucket --bucket=entryState
    Write-Host "Chezmoi entry state cleared. All files will be reprocessed on next 'chezmoi apply'." -ForegroundColor Yellow
    Write-Host "Warning: This may cause unexpected changes. Use 'chezmoi apply --dry-run' first." -ForegroundColor Yellow
}

function Invoke-ChezmoiSigning {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CertificateThumbprint
    )

    # Signs PowerShell scripts in the Chezmoi source directory and repository root
    $chezmoiSourceDir = chezmoi source-path
    if ($LASTEXITCODE -ne 0 -or -not $chezmoiSourceDir) {
        Write-Host "Error: Failed to get Chezmoi source directory" -ForegroundColor Red
        return
    }

    # Detect repository root robustly:
    # Prefer 'git rev-parse --show-toplevel' so the repo is found wherever it lives
    # (e.g. ~/.local/share/chezmoi, ~/projects/dotfiles, etc.), regardless of the
    # chezmoi source layout. Fall back to the parent of the source dir (which
    # matches the default 'home/' subdirectory layout used by this repo).
    $repoRoot = $null
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Push-Location $chezmoiSourceDir
        try {
            $gitTopLevel = git rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and $gitTopLevel) {
                # git returns forward slashes on Windows; normalise to native separators
                $repoRoot = (Resolve-Path -LiteralPath $gitTopLevel.Trim()).Path
            }
        }
        finally {
            Pop-Location
        }
    }

    if (-not $repoRoot) {
        $repoRoot = Split-Path -Parent $chezmoiSourceDir
    }

    $signingScript = Join-Path -Path $chezmoiSourceDir -ChildPath "dot_config\powershell\scripts\Sign-PowerShellScripts.ps1"

    if (-not (Test-Path $signingScript)) {
        Write-Host "Error: Sign-PowerShellScripts.ps1 not found at $signingScript" -ForegroundColor Red
        return
    }

    # Sign all PowerShell scripts in the repository (includes tests/, .github/, etc.)
    & $signingScript -CertificateThumbprint $CertificateThumbprint -Path $repoRoot
}

function Get-ChezmoiConfigTemplate {
    <#
    .SYNOPSIS
    Returns the path of the chezmoi config template, or $null when there is none.
    .DESCRIPTION
    Usually <source-path>/.chezmoi.yaml.tmpl. Private helper for Update-Chezmoi.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Guard and catch: with $ErrorActionPreference = 'Stop' (as under GitHub
    # Actions' `shell: pwsh`) a missing chezmoi would otherwise throw.
    if (-not (Get-Command chezmoi -CommandType Application -ErrorAction SilentlyContinue)) { return $null }

    $sourceDir = $null
    try { $sourceDir = & chezmoi source-path 2>$null }
    catch { return $null }
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourceDir)) { return $null }

    foreach ($ext in @('yaml', 'toml', 'json', 'jsonc', 'yml')) {
        $candidate = Join-Path $sourceDir ".chezmoi.$ext.tmpl"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

function Test-ChezmoiConfigChanged {
    <#
    .SYNOPSIS
    Returns $true when `chezmoi init` should run.
    .DESCRIPTION
    Compares the SHA256 chezmoi recorded for the config template (its
    configState bucket, the same data behind its "config file template has
    changed" warning) with the template on disk. When either side cannot be
    determined this returns $true and lets init run: a redundant init is
    harmless, a skipped one is not.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $template = Get-ChezmoiConfigTemplate
    if (-not $template) { return $true }

    $state = $null
    try { $state = & chezmoi state get --bucket=configState --key=configState 2>$null }
    catch { return $true }
    if ($LASTEXITCODE -ne 0 -or -not $state) { return $true }

    $stored = $null
    try {
        $stored = ($state | ConvertFrom-Json).configTemplateContentsSHA256
    }
    catch {
        return $true
    }
    if ([string]::IsNullOrWhiteSpace($stored)) { return $true }

    $actual = (Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash
    if ([string]::IsNullOrWhiteSpace($actual)) { return $true }

    return ($stored -ne $actual)
}

function Get-ChezmoiExpectedBranch {
    <#
    .SYNOPSIS
    The branch the chezmoi source repository should be on.

    .DESCRIPTION
    Honours CHEZMOI_UP_BRANCH, else asks git which branch origin's HEAD points
    at (so a repository that renames its default branch keeps working), else
    falls back to main. Private helper for Update-Chezmoi.

    .PARAMETER SourceDir
    The chezmoi source directory.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][string]$SourceDir)

    if (-not [string]::IsNullOrWhiteSpace($env:CHEZMOI_UP_BRANCH)) {
        return $env:CHEZMOI_UP_BRANCH
    }

    $head = (& git -C $SourceDir symbolic-ref --short -q refs/remotes/origin/HEAD 2>$null | Out-String).Trim()
    if (-not [string]::IsNullOrWhiteSpace($head)) {
        return ($head -replace '^origin/', '')
    }

    return 'main'
}

function Get-ChezmoiBranchConfirmation {
    <#
    .SYNOPSIS
    Ask a yes/no question, defaulting to "no" when nobody can answer.

    .DESCRIPTION
    Non-interactive sessions always answer "no" so an automated run is warned
    but never blocked. CHEZMOI_UP_ASSUME_YES=1 answers yes,
    CHEZMOI_UP_ASSUME_NO=1 answers no. Private helper for Update-Chezmoi.

    .PARAMETER Message
    The question to ask.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory = $true)][string]$Message)

    if ($env:CHEZMOI_UP_ASSUME_YES -eq '1') { return $true }
    if ($env:CHEZMOI_UP_ASSUME_NO -eq '1') { return $false }
    if (-not [Environment]::UserInteractive) { return $false }
    if ([Console]::IsInputRedirected) { return $false }

    $answer = Read-Host "$Message [y/N]"
    return ($answer -match '^\s*(y|yes)\s*$')
}

function Test-ChezmoiSourceBranch {
    <#
    .SYNOPSIS
    Warn when the chezmoi source repository is off its default branch, and
    offer to switch and pull.

    .DESCRIPTION
    `chezmoi update` pulls whichever branch is checked out, so a forgotten
    feature branch would otherwise be applied to the machine silently.

    Always returns without failing: working on a feature branch is a legitimate
    way to test dotfiles changes, so this warns and offers rather than blocking
    the run. Private helper for Update-Chezmoi.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive helper; progress output is the point.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Prompts for the branch switch itself; -WhatIf would be redundant.')]
    [CmdletBinding()]
    param()

    if ($env:CHEZMOI_UP_SKIP_BRANCH_CHECK -eq '1') { return }
    if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) { return }

    try { $sourceDir = (& chezmoi source-path 2>$null | Out-String).Trim() }
    catch { return }
    if ([string]::IsNullOrWhiteSpace($sourceDir) -or -not (Test-Path -LiteralPath $sourceDir)) { return }

    # A source directory that is not a git checkout has no branch to be wrong.
    $null = & git -C $sourceDir rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0) { return }

    $expected = Get-ChezmoiExpectedBranch -SourceDir $sourceDir
    $current = (& git -C $sourceDir symbolic-ref --short -q HEAD 2>$null | Out-String).Trim()

    if ($current -eq $expected) { return }

    $where = if ([string]::IsNullOrWhiteSpace($current)) { 'detached HEAD' } else { "'$current'" }
    if ([string]::IsNullOrWhiteSpace($current)) {
        Write-Host "[WARN] Source repository is in detached HEAD state, not on '$expected'." -ForegroundColor Yellow
    }
    else {
        Write-Host "[WARN] Source repository is on '$current', not '$expected'." -ForegroundColor Yellow
    }
    Write-Host '[WARN] chezmoi update pulls whichever branch is checked out.' -ForegroundColor Yellow

    if (-not (Get-ChezmoiBranchConfirmation -Message "Switch to '$expected' and pull?")) {
        Write-Host "==> Staying on $where."
        return
    }

    # Switching with uncommitted changes would either fail or drag the changes
    # onto the default branch; neither is something to do behind the user's back.
    $dirty = (& git -C $sourceDir status --porcelain 2>$null | Out-String).Trim()
    if (-not [string]::IsNullOrWhiteSpace($dirty)) {
        Write-Error 'Source repository has uncommitted changes; commit or stash them first.' -ErrorAction Continue
        Write-Host "==> Continuing on $where."
        return
    }

    Write-Host "==> Switching to '$expected'" -ForegroundColor Blue
    & git -C $sourceDir checkout $expected
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Could not check out '$expected'; continuing on $where." -ErrorAction Continue
        return
    }

    # --ff-only: never create a merge commit in the dotfiles source behind the
    # user's back. A diverged branch is reported instead.
    & git -C $sourceDir pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Could not fast-forward '$expected'; resolve it manually." -ErrorAction Continue
        return
    }
}

function Update-Chezmoi {
    <#
    .SYNOPSIS
    Pull, re-init when the config template changed, then apply, stopping on the
    first failure.

    .DESCRIPTION
    Replaces the usual `chezmoi update; chezmoi init; chezmoi apply` dance.
    Each step is a gate: if one fails the run stops there, so a failed pull can
    never be followed by an apply of half-updated source.

    The steps are:
      0. Branch guard - warn when the source repo is not on its default branch
         (usually main) and offer to switch and pull.
      1. `chezmoi update --apply=false` - pull the source repo only. Applying
         here would use the OLD config, which breaks when the pull introduces a
         template variable the current config does not have yet.
      2. `chezmoi init` - only when the config template actually changed.
         Skipping is logged.
      3. `chezmoi apply` - apply with the freshly generated config.

    .PARAMETER ForceInit
    Run `chezmoi init` even when the config template is unchanged.

    .EXAMPLE
    Update-Chezmoi
    Pull, conditionally re-init, and apply.

    .EXAMPLE
    czu -ForceInit
    Same, but always regenerate the config file.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive helper; progress output is the point.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Thin wrapper around chezmoi, which owns its own --dry-run/--force flags.')]
    [CmdletBinding()]
    param(
        [Alias('f')]
        [switch]$ForceInit
    )

    if (-not (Get-Command chezmoi -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Error 'chezmoi is not installed or not in PATH' -ErrorAction Continue
        return
    }

    Test-ChezmoiSourceBranch

    Write-Host '==> Pulling the source repository' -ForegroundColor Blue
    & chezmoi update --apply=false
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'chezmoi update failed; not continuing to init/apply' -ErrorAction Continue
        return
    }

    $runInit = $false
    $reason = ''
    if ($ForceInit) {
        $runInit = $true
        $reason = 'forced'
    }
    elseif (Test-ChezmoiConfigChanged) {
        $runInit = $true
        $reason = 'config template changed'
    }

    if ($runInit) {
        Write-Host "==> Regenerating the config file ($reason)" -ForegroundColor Blue
        & chezmoi init
        if ($LASTEXITCODE -ne 0) {
            Write-Error 'chezmoi init failed; not continuing to apply' -ErrorAction Continue
            return
        }
    }
    else {
        Write-Host '==> Config template unchanged, skipping chezmoi init'
    }

    Write-Host '==> Applying' -ForegroundColor Blue
    & chezmoi apply
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'chezmoi apply failed' -ErrorAction Continue
        return
    }

    Write-Host '[OK] Dotfiles are up to date' -ForegroundColor Green
}
