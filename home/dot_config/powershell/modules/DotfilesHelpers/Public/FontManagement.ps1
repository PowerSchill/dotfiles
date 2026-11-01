# Font management utilities
#
# Functions for installing Nerd Fonts. Windows Terminal settings.json patching
# (font face + default profile) lives in WindowsTerminal.ps1.

function Test-NerdFontInstalled {
    <#
    .SYNOPSIS
    Returns $true if a Nerd Font matching the given name is registered.

    .PARAMETER Name
    The Nerd Font family name (as passed to Install-NerdFont), e.g. 'FiraCode'.
    Matching ignores spaces, so 'FiraCode' matches the registered
    'FiraCodeNerdFont-Regular (TrueType)' value.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [ValidatePattern('^[A-Za-z0-9._ -]+$')]
        [string]$Name = 'FiraCode'
    )

    $needle = ($Name -replace '\s', '')
    $keys = @(
        'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    )

    foreach ($key in $keys) {
        if (-not (Test-Path -Path $key)) { continue }
        $props = (Get-ItemProperty -Path $key).PSObject.Properties
        foreach ($prop in $props) {
            if ($prop.Name -like 'PS*') { continue }
            $normalized = ($prop.Name -replace '\s', '')
            if ($normalized -like "*${needle}NerdFont*") { return $true }
        }
    }

    return $false
}

function Invoke-NerdFontInstaller {
    <#
    .SYNOPSIS
    Performs the actual Nerd Font install via the (PowerShell 7) NerdFonts module.

    .DESCRIPTION
    chezmoi runs scripts under Windows PowerShell 5.1, but the NerdFonts module
    is PowerShell 7 only, so the install is delegated to pwsh. Kept private so
    Install-DotfilesNerdFont can be unit-tested by mocking this function.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9._-]+$')]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope
    )

    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwshCmd) {
        Write-Warning "pwsh (PowerShell 7) not found; cannot install Nerd Font '$Name'. Install PowerShell 7 first."
        return $false
    }

    if (-not $PSCmdlet.ShouldProcess($Name, 'Install Nerd Font')) { return $false }

    # $Name and $Scope are constrained by ValidatePattern/ValidateSet above, so
    # interpolating them into the command string is safe from injection.
    $inner = "Install-PSResource -Name NerdFonts -Scope CurrentUser -TrustRepository -Quiet -ErrorAction Stop; " +
    "Install-NerdFont -Name $Name -Scope $Scope -Confirm:`$false -ErrorAction Stop"

    & $pwshCmd.Source -ExecutionPolicy Bypass -NoProfile -NonInteractive -Command $inner 2>&1 |
        ForEach-Object { Write-Verbose ([string]$_) }

    return ($LASTEXITCODE -eq 0)
}

function Install-DotfilesNerdFont {
    <#
    .SYNOPSIS
    Idempotently installs a Nerd Font and verifies it registered.

    .PARAMETER Name
    Nerd Font family name (default 'FiraCode').

    .PARAMETER Scope
    Install scope: CurrentUser (default) or AllUsers.

    .PARAMETER Force
    Reinstall even if the font already appears to be installed.

    .EXAMPLE
    Install-DotfilesNerdFont -Name FiraCode -Scope CurrentUser
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidatePattern('^[A-Za-z0-9._-]+$')]
        [string]$Name = 'FiraCode',

        [Parameter()]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope = 'CurrentUser',

        [switch]$Force
    )

    if ((Test-NerdFontInstalled -Name $Name) -and -not $Force) {
        Write-Host "[OK] $Name Nerd Font already installed" -ForegroundColor Green
        return [pscustomobject]@{ Name = $Name; Installed = $true; Action = 'AlreadyInstalled' }
    }

    if (-not $PSCmdlet.ShouldProcess($Name, 'Install Nerd Font')) {
        return [pscustomobject]@{ Name = $Name; Installed = (Test-NerdFontInstalled -Name $Name); Action = 'Skipped' }
    }

    Write-Host "Installing $Name Nerd Font..." -ForegroundColor Cyan
    $ok = Invoke-NerdFontInstaller -Name $Name -Scope $Scope
    $installed = Test-NerdFontInstalled -Name $Name

    if ($ok -and $installed) {
        Write-Host "[OK] $Name Nerd Font installed" -ForegroundColor Green
        return [pscustomobject]@{ Name = $Name; Installed = $true; Action = 'Installed' }
    }

    Write-Warning "Failed to install $Name Nerd Font. Install manually with: pwsh -Command 'Install-NerdFont -Name $Name -Scope $Scope'"
    return [pscustomobject]@{ Name = $Name; Installed = $false; Action = 'Failed' }
}
