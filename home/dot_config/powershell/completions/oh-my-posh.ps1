# oh-my-posh initialization for PowerShell

# Initialize oh-my-posh if available, with a timeout guard to avoid hanging the profile
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $ompTimeoutMs = 3000
    $parsedTimeout = 0
    if ($env:OMP_TIMEOUT_MS -and
        [int]::TryParse($env:OMP_TIMEOUT_MS, [ref]$parsedTimeout) -and
        $parsedTimeout -gt 0) {
        $ompTimeoutMs = $parsedTimeout
    }

    $ompCmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    $ompTempFile = $null
    $ompOutput = $null
    try {
        $ompTempFile = [System.IO.Path]::GetTempFileName()
        $ompConfigPath = Join-Path $HOME '.ohmyposh.omp.yaml'
        $ompProc = Start-Process -FilePath $ompCmd.Source `
            -ArgumentList 'init', 'pwsh', '--eval', '--config', $ompConfigPath `
            -NoNewWindow -RedirectStandardOutput $ompTempFile -PassThru -ErrorAction Stop
        if ($ompProc.WaitForExit($ompTimeoutMs)) {
            $ompOutput = Get-Content $ompTempFile -Raw -ErrorAction SilentlyContinue
        } else {
            try { $ompProc.Kill() } catch { }
            Write-Host "`n(oh-my-posh init timed out after $([math]::Round($ompTimeoutMs / 1000, 1))s; skipping)" -ForegroundColor DarkYellow
        }
    } catch {
        Write-Host "(oh-my-posh init failed: $($_.Exception.Message))" -ForegroundColor DarkYellow
    } finally {
        if ($ompTempFile -and (Test-Path $ompTempFile -ErrorAction SilentlyContinue)) {
            Remove-Item $ompTempFile -ErrorAction SilentlyContinue
        }
    }
    if ($ompOutput) { Invoke-Expression $ompOutput }
}
