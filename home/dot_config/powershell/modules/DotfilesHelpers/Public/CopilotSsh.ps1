# GitHub Copilot CLI SSH helper
#
# Connect-CopilotSsh (aliased 'copilot-ssh' / 'copilot_ssh') - SSH into a host
# with GitHub tokens forwarded from a 1Password Environment.
#
# See docs/copilot-cli.md for the full design. In short: it reads
# COPILOT_GITHUB_TOKEN (for GitHub Copilot CLI) and, if present, GH_TOKEN (for
# the GitHub CLI) from a 1Password Environment via `op run`, then forwards them
# to the remote session using SSH SendEnv so both tools can authenticate on
# headless servers that have no secure vault. Tokens are never written to disk.

function Get-DotfilesSshHost {
    <#
    .SYNOPSIS
        Return concrete host aliases defined in the user's SSH client config.
    .DESCRIPTION
        Parses ~/.ssh/config (following `Include` directives) and returns the
        literal `Host` aliases, excluding pattern entries (those containing
        wildcards '*'/'?' or negations '!'). Used to power tab-completion for
        Connect-CopilotSsh. Never throws; returns an empty array on any error.
    .PARAMETER Filter
        Optional prefix; only hosts matching "<Filter>*" (case-insensitive) are
        returned.
    .PARAMETER SshDirectory
        The SSH client directory to read (config + Include files). Defaults to
        ~/.ssh. Exposed primarily so tests can point at a fixture directory.
    #>
    [CmdletBinding()]
    param(
        [string]$Filter,
        [string]$SshDirectory = (Join-Path $HOME '.ssh')
    )

    $rootConfig = Join-Path $SshDirectory 'config'
    $sshDir = $SshDirectory
    $hosts = [System.Collections.Generic.List[string]]::new()
    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    function Read-Config {
        param([string]$Path)

        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        # Expand a possible leading ~ and make Include globs relative to ~/.ssh.
        if ($Path -like '~*') { $Path = Join-Path $HOME ($Path.Substring(1).TrimStart('/', '\')) }
        if (-not [System.IO.Path]::IsPathRooted($Path)) { $Path = Join-Path $sshDir $Path }

        $matched = @()
        try { $matched = @(Resolve-Path -Path $Path -ErrorAction SilentlyContinue) } catch { $matched = @() }

        foreach ($resolved in $matched) {
            $file = $resolved.Path
            if (-not $visited.Add($file)) { continue }
            if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }

            $lines = @()
            try { $lines = Get-Content -LiteralPath $file -ErrorAction SilentlyContinue } catch { $lines = @() }

            foreach ($line in $lines) {
                $trimmed = $line.Trim()
                if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }

                # Split keyword from its arguments; allow "Key value" and "Key=value".
                $tokens = $trimmed -split '[\s=]+'
                if ($tokens.Count -lt 2) { continue }
                $keyword = $tokens[0]

                if ($keyword -ieq 'Include') {
                    foreach ($inc in $tokens[1..($tokens.Count - 1)]) { Read-Config -Path $inc }
                }
                elseif ($keyword -ieq 'Host') {
                    foreach ($name in $tokens[1..($tokens.Count - 1)]) {
                        if ($name -match '[*?]' -or $name.StartsWith('!')) { continue }
                        if (-not $hosts.Contains($name)) { $hosts.Add($name) }
                    }
                }
            }
        }
    }

    Read-Config -Path $rootConfig

    $result = $hosts
    if (-not [string]::IsNullOrEmpty($Filter)) {
        $result = $hosts | Where-Object { $_ -like "$Filter*" }
    }
    return @($result | Sort-Object -Unique)
}

function ConvertFrom-SshConfigOutput {
    <#
    .SYNOPSIS
        Extract the effective hostname/port from `ssh -G` output.
    .DESCRIPTION
        `ssh -G <args>` prints the fully resolved client configuration for a
        destination (honouring ~/.ssh/config aliases, HostName/Port overrides
        and -o flags) without connecting. This parses the two keys the
        pre-flight probe needs. Returns $null when no hostname was resolved,
        which callers treat as "skip the probe".
    .PARAMETER Lines
        The raw lines emitted by `ssh -G`.
    #>
    [CmdletBinding()]
    param([string[]]$Lines)

    $hostName = $null
    $port = $null
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line.Trim() -split '\s+', 2
        if ($parts.Count -lt 2) { continue }
        switch ($parts[0].ToLowerInvariant()) {
            'hostname' { $hostName = $parts[1].Trim() }
            'port' { $port = $parts[1].Trim() }
        }
    }

    if ([string]::IsNullOrWhiteSpace($hostName)) { return $null }
    $portValue = 22
    if (-not [string]::IsNullOrWhiteSpace($port)) { [void][int]::TryParse($port, [ref]$portValue) }
    return [PSCustomObject]@{ HostName = $hostName; Port = $portValue }
}

function Select-CopilotSshAzureVm {
    <#
    .SYNOPSIS
        Pick the Azure VMs that correspond to an SSH host.
    .DESCRIPTION
        Matches the VM name against the host and against its short form
        (vm01.example.com -> vm01), then falls back to matching the host
        against the VM's public/private IP addresses. Pure string logic so it
        is testable without the Azure CLI.
    .PARAMETER Row
        TSV rows as produced by
        `az vm list -d -o tsv --query '[].[name,resourceGroup,powerState,publicIps,privateIps]'`.
    .PARAMETER HostName
        The resolved SSH host (name, FQDN or IP address).
    #>
    [CmdletBinding()]
    param(
        [string[]]$Row,
        [string]$HostName
    )

    $short = $HostName.Split('.')[0]
    $results = @()

    foreach ($line in $Row) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $cols = $line -split "`t"
        if ($cols.Count -lt 3) { continue }

        $name = $cols[0].Trim()
        $matched = ($name -ieq $HostName) -or ($name -ieq $short)

        if (-not $matched -and $cols.Count -ge 4) {
            # publicIps/privateIps may hold a comma-separated list.
            $ips = @()
            foreach ($field in $cols[3..($cols.Count - 1)]) {
                $ips += ($field -split ',' | ForEach-Object { $_.Trim() })
            }
            $matched = $ips -contains $HostName
        }

        if ($matched) {
            $results += [PSCustomObject]@{
                Name          = $name
                ResourceGroup = $cols[1].Trim()
                PowerState    = $cols[2].Trim()
            }
        }
    }

    return @($results)
}

function Test-CopilotSshPort {
    <#
    .SYNOPSIS
        Fast TCP reachability probe for an SSH endpoint.
    .DESCRIPTION
        Opens a TCP connection with a hard timeout so an unreachable host fails
        in seconds instead of hanging on ssh's own connect timeout. DNS failures
        and refused connections both return $false.
    #>
    [CmdletBinding()]
    param(
        [string]$HostName,
        [int]$Port = 22,
        [int]$TimeoutSeconds = 3
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds))) {
            return $false
        }
        $client.EndConnect($async)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

function Get-CopilotSshConfirmation {
    <#
    .SYNOPSIS
        Ask a yes/no question, defaulting to "no" when nobody can answer.
    .DESCRIPTION
        Non-interactive sessions (redirected stdin, no user interaction) always
        answer "no" so scripts never block on the prompt. Set
        COPILOT_SSH_ASSUME_YES=1 to answer "yes" automatically.
    #>
    [CmdletBinding()]
    param([string]$Message)

    if ($env:COPILOT_SSH_ASSUME_YES -eq '1') { return $true }
    if ($env:COPILOT_SSH_ASSUME_NO -eq '1') { return $false }
    if (-not [Environment]::UserInteractive) { return $false }
    if ([Console]::IsInputRedirected) { return $false }

    $answer = Read-Host "$Message [y/N]"
    return ($answer -match '^\s*(y|yes)\s*$')
}

function Wait-CopilotSshPort {
    <#
    .SYNOPSIS
        Poll an SSH endpoint until it accepts connections (or time out).
    #>
    [CmdletBinding()]
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutSeconds = 180
    )

    $waited = 0
    Write-Host "copilot-ssh: waiting for ${HostName}:${Port} to accept connections" -NoNewline
    while ($waited -lt $TimeoutSeconds) {
        if (Test-CopilotSshPort -HostName $HostName -Port $Port -TimeoutSeconds 3) {
            Write-Host ' up'
            return $true
        }
        Write-Host '.' -NoNewline
        Start-Sleep -Seconds 5
        $waited += 5
    }
    Write-Host ' timed out'
    return $false
}

function Invoke-CopilotSshAzureRecovery {
    <#
    .SYNOPSIS
        Try to bring a stopped Azure VM back up after a failed reachability probe.
    .DESCRIPTION
        Looks the host up with `az vm list -d`. When the VM is stopped or
        deallocated the user is offered to start it, and the connection resumes
        once the SSH port answers. Returns $true only when the host became
        reachable.
    #>
    [CmdletBinding()]
    param(
        [string]$HostName,
        [int]$Port
    )

    if (-not (Get-Command az -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Host "copilot-ssh: install the Azure CLI ('az') to check whether the VM is stopped."
        return $false
    }

    Write-Host "copilot-ssh: looking up '$HostName' in Azure..."
    $rows = @()
    try {
        $rows = @(& az vm list -d --only-show-errors -o tsv `
                --query '[].[name,resourceGroup,powerState,publicIps,privateIps]' 2>$null)
    }
    catch {
        $rows = @()
    }

    $vmMatches = @(Select-CopilotSshAzureVm -Row $rows -HostName $HostName)

    if ($vmMatches.Count -eq 0) {
        # Name the subscription and the VM count: by far the most common cause
        # is the wrong subscription being active, and the old message gave no
        # way to tell that apart from "the VM really isn't there".
        $short = $HostName.Split('.')[0]
        $subName = (& az account show --only-show-errors --query name -o tsv 2>$null | Out-String).Trim()
        $subId = (& az account show --only-show-errors --query id -o tsv 2>$null | Out-String).Trim()
        $subscription = if ([string]::IsNullOrWhiteSpace($subName)) { '' } else { "$subName ($subId)" }
        $vmCount = (& az vm list --only-show-errors --query 'length(@)' -o tsv 2>$null | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($subscription)) { $subscription = "<unknown; run 'az login'>" }
        if ([string]::IsNullOrWhiteSpace($vmCount)) { $vmCount = '0' }

        Write-Host "copilot-ssh: no Azure VM matches '$HostName' (also searched for the short name '$short')."
        Write-Host "            Subscription: $subscription ($vmCount VMs)."
        if ($vmCount -eq '0') {
            Write-Host "            That subscription has no VMs at all - check 'az login' / 'az account show'."
        }
        else {
            Write-Host "            Wrong subscription? Switch with: az account set --subscription <name-or-id>"
        }
        return $false
    }

    if ($vmMatches.Count -gt 1) {
        Write-Host "copilot-ssh: several Azure VMs match '$HostName'; not guessing:"
        foreach ($vm in $vmMatches) {
            Write-Host ("            - {0} (resource group {1}, {2})" -f $vm.Name, $vm.ResourceGroup, $vm.PowerState)
        }
        return $false
    }

    $vm = $vmMatches[0]
    if ($vm.PowerState -match 'running') {
        Write-Host "copilot-ssh: Azure VM '$($vm.Name)' is running but ${HostName}:${Port} is unreachable."
        Write-Host '            Check the NSG rules, the VPN/network path or sshd on the VM.'
        return $false
    }

    $state = if ([string]::IsNullOrWhiteSpace($vm.PowerState)) { 'in an unknown state' } else { $vm.PowerState }
    Write-Host "copilot-ssh: Azure VM '$($vm.Name)' (resource group $($vm.ResourceGroup)) is $state."
    if (-not (Get-CopilotSshConfirmation -Message 'copilot-ssh: start it now?')) {
        Write-Host 'copilot-ssh: not starting the VM; aborting.'
        return $false
    }

    & az vm start --only-show-errors -g $vm.ResourceGroup -n $vm.Name | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "copilot-ssh: 'az vm start' failed for '$($vm.Name)'."
        return $false
    }
    Write-Host "copilot-ssh: started '$($vm.Name)'."

    $startTimeout = 180
    if ($env:COPILOT_SSH_START_TIMEOUT) { [void][int]::TryParse($env:COPILOT_SSH_START_TIMEOUT, [ref]$startTimeout) }
    return (Wait-CopilotSshPort -HostName $HostName -Port $Port -TimeoutSeconds $startTimeout)
}

function Test-CopilotSshPreflight {
    <#
    .SYNOPSIS
        Fail fast when the SSH host is unreachable.
    .DESCRIPTION
        Resolves the destination with `ssh -G` and probes its TCP port. Returns
        $true when the host answers, when the check could not run (no
        destination resolved), or when the Azure recovery brought the VM back
        up; $false when the connection should be abandoned.

        Set COPILOT_SSH_SKIP_PREFLIGHT=1 to bypass, or
        COPILOT_SSH_PREFLIGHT_TIMEOUT to change the 3 second probe timeout.
    .PARAMETER SshArgument
        The arguments that will be passed to ssh (destination included).
    #>
    [CmdletBinding()]
    param([string[]]$SshArgument)

    if ($env:COPILOT_SSH_SKIP_PREFLIGHT -eq '1') { return $true }

    $config = @()
    try {
        $config = @(& ssh -G @SshArgument 2>$null)
    }
    catch {
        $config = @()
    }

    $endpoint = ConvertFrom-SshConfigOutput -Lines $config
    # No destination resolved (e.g. ssh could not parse the args): skip the
    # probe rather than blocking a connection that might still work.
    if ($null -eq $endpoint) { return $true }

    $timeout = 3
    if ($env:COPILOT_SSH_PREFLIGHT_TIMEOUT) { [void][int]::TryParse($env:COPILOT_SSH_PREFLIGHT_TIMEOUT, [ref]$timeout) }

    if (Test-CopilotSshPort -HostName $endpoint.HostName -Port $endpoint.Port -TimeoutSeconds $timeout) {
        return $true
    }

    Write-Host "copilot-ssh: $($endpoint.HostName):$($endpoint.Port) is not reachable."
    return (Invoke-CopilotSshAzureRecovery -HostName $endpoint.HostName -Port $endpoint.Port)
}

function Connect-CopilotSsh {
    <#
    .SYNOPSIS
        SSH into a host with GitHub tokens forwarded from a 1Password Environment.
    .DESCRIPTION
        Reads COPILOT_GITHUB_TOKEN (for GitHub Copilot CLI) and, if present,
        GH_TOKEN (for the GitHub CLI) from a 1Password Environment via a single
        `op run`, then forwards them to the remote session with SSH SendEnv so
        both tools can authenticate on headless servers that have no secure
        vault. The tokens are never written to disk; they live only in
        1Password, transiently in this session, the encrypted SSH channel, and
        the remote session's environment.

        The remote sshd must `AcceptEnv COPILOT_GITHUB_TOKEN GH_TOKEN`. Copilot
        CLI reads COPILOT_GITHUB_TOKEN (precedence over GH_TOKEN); the `gh` CLI
        reads GH_TOKEN.

        Requirements:
          - 1Password CLI (`op`) >= 2.33.0-beta.02 with the desktop-app
            integration enabled (1Password -> Settings -> Developer ->
            "Integrate with 1Password CLI").
          - OP_COPILOT_ENVIRONMENT_ID set to your 1Password Environment ID
            (rendered from the chezmoi `opCopilotEnvironmentId` variable). The
            Environment must contain COPILOT_GITHUB_TOKEN; GH_TOKEN is optional.

        Pre-flight checks are fatal: if `ssh` or `op` is missing, or
        OP_COPILOT_ENVIRONMENT_ID is unset, the command aborts without
        connecting (rather than silently opening a token-less session that
        would leave copilot/gh unauthenticated on the server).
    .PARAMETER HostName
        The SSH destination (e.g. svldev). Tab-completes from the `Host` aliases
        in your ~/.ssh/config.
    .PARAMETER SshArgument
        Extra arguments passed through to ssh. Because ssh flags such as -p / -o
        collide with PowerShell's parameter binder, pass them after a `--`
        separator, e.g. `copilot-ssh svldev -- -A -p 2222`.
    .EXAMPLE
        copilot-ssh svldev
        Connect to svldev with the tokens forwarded.
    .EXAMPLE
        copilot-ssh svldev -- -A -p 2222
        Connect with SSH agent forwarding on port 2222.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $module = Get-Module DotfilesHelpers
                if (-not $module) { return }
                & $module { param($w) Get-DotfilesSshHost -Filter $w } $wordToComplete |
                    ForEach-Object {
                        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                    }
            })]
        [Alias('Host', 'Destination')]
        [string]$HostName,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$SshArgument,

        [Alias('h')]
        [switch]$Help
    )

    if ($Help -or $HostName -in @('-h', '--help', '-?')) {
        Write-Host 'Usage: copilot-ssh <host> [-- ssh options...]'
        Write-Host 'SSH with COPILOT_GITHUB_TOKEN (and GH_TOKEN) forwarded from a 1Password Environment.'
        Write-Host 'The <host> argument tab-completes from your ~/.ssh/config Host entries.'
        Write-Host 'Pass extra ssh flags after a -- separator, e.g.: copilot-ssh svldev -- -A -p 2222'
        return
    }

    if ([string]::IsNullOrEmpty($HostName) -and -not $SshArgument) {
        Write-Host 'Usage: copilot-ssh <host> [-- ssh options...]'
        return
    }

    # ssh expects: ssh [options] destination [command]
    $passthrough = @()
    if ($SshArgument) { $passthrough += $SshArgument }
    if (-not [string]::IsNullOrEmpty($HostName)) { $passthrough += $HostName }

    # Pre-flight checks. Each is fatal: the whole purpose of this helper is to
    # forward GitHub tokens, so if we cannot, we stop rather than silently
    # opening a token-less ssh session (which would leave copilot/gh
    # unauthenticated on the server in a confusing way). Write-Error uses
    # -ErrorAction Continue so the abort stays non-terminating (emit message,
    # then return) even when the caller's $ErrorActionPreference is 'Stop',
    # as it is under GitHub Actions' `shell: pwsh`.
    if (-not (Get-Command ssh -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Error "copilot-ssh: 'ssh' (OpenSSH client) was not found on PATH. Install the OpenSSH client and try again." -ErrorAction Continue
        return
    }

    # Reachability pre-flight, before unlocking 1Password: a short TCP probe so
    # an unreachable host fails in ~3s, with an Azure CLI assisted recovery
    # (offer to start a stopped VM) when the probe fails.
    if (-not (Test-CopilotSshPreflight -SshArgument $passthrough)) {
        Write-Error "copilot-ssh: aborting; '$HostName' is not reachable." -ErrorAction Continue
        return
    }

    if (-not (Get-Command op -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Error ("copilot-ssh: '1Password CLI' (op) was not found on PATH; aborting (tokens cannot be forwarded).`n" +
            "            1. Install it: https://developer.1password.com/docs/cli/get-started/ (>= 2.33.0-beta.02).`n" +
            "            2. Enable the desktop-app integration: 1Password -> Settings -> Developer ->`n" +
            "               'Integrate with 1Password CLI', then restart your terminal.`n" +
            "            See docs/copilot-cli.md for details.") -ErrorAction Continue
        return
    }

    $envId = $env:OP_COPILOT_ENVIRONMENT_ID
    if ([string]::IsNullOrEmpty($envId)) {
        Write-Error ("copilot-ssh: OP_COPILOT_ENVIRONMENT_ID is not set; aborting (tokens cannot be forwarded).`n" +
            "            Set the chezmoi 'opCopilotEnvironmentId' variable (see docs/copilot-cli.md).") -ErrorAction Continue
        return
    }

    # Read both tokens in a single `op run` (one 1Password unlock) so the
    # interactive ssh below is not wrapped by op run, whose stdout/stderr masking
    # can disturb a TTY. `--no-masking` is required because Environment values
    # are hidden by default. A short child PowerShell prints the two values
    # tab-separated (GitHub tokens never contain a tab) from the injected env.
    $psExe = (Get-Process -Id $PID -ErrorAction SilentlyContinue).Path
    if (-not $psExe) {
        $psExe = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'powershell' }
    }
    $childCmd = '[Console]::Out.Write(([string]$env:COPILOT_GITHUB_TOKEN) + [char]9 + ([string]$env:GH_TOKEN))'
    $creds = & op run --environment $envId --no-masking -- $psExe -NoProfile -NonInteractive -Command $childCmd 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "copilot-ssh: failed to read tokens from 1Password Environment '$envId'. Ensure 'op' >= 2.33.0-beta.02, the desktop-app integration is enabled (1Password -> Settings -> Developer), and the Environment ID is correct." -ErrorAction Continue
        return
    }

    $parts = ([string]$creds) -split "`t", 2
    $copilotToken = $parts[0]
    $ghToken = if ($parts.Count -ge 2) { $parts[1] } else { '' }

    if ([string]::IsNullOrEmpty($copilotToken)) {
        Write-Error "copilot-ssh: COPILOT_GITHUB_TOKEN not found in Environment '$envId'." -ErrorAction Continue
        return
    }

    # Forward COPILOT_GITHUB_TOKEN always; GH_TOKEN only when it is set.
    $sshEnvOpts = @('-o', 'SendEnv=COPILOT_GITHUB_TOKEN')
    if (-not [string]::IsNullOrEmpty($ghToken)) {
        $sshEnvOpts += @('-o', 'SendEnv=GH_TOKEN')
    }

    # Export the tokens for the ssh child process, then restore the previous
    # environment afterwards so they don't linger in this interactive session.
    $prevCopilot = $env:COPILOT_GITHUB_TOKEN
    $prevGh = $env:GH_TOKEN
    try {
        $env:COPILOT_GITHUB_TOKEN = $copilotToken
        if (-not [string]::IsNullOrEmpty($ghToken)) {
            $env:GH_TOKEN = $ghToken
        }
        & ssh @sshEnvOpts @passthrough
    }
    finally {
        if ($null -eq $prevCopilot) { Remove-Item Env:COPILOT_GITHUB_TOKEN -ErrorAction SilentlyContinue }
        else { $env:COPILOT_GITHUB_TOKEN = $prevCopilot }
        if ($null -eq $prevGh) { Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue }
        else { $env:GH_TOKEN = $prevGh }
    }
}
