# Task (go-task) completion for PowerShell
# Documentation: https://taskfile.dev/docs/installation#setup-completions

# Initialize task completions if available, with a timeout guard to avoid hanging the profile
if (Get-Command task -ErrorAction SilentlyContinue) {
    $taskTimeoutMs = 3000
    $parsedTimeout = 0
    if ($env:TASK_COMPLETION_TIMEOUT_MS -and
        [int]::TryParse($env:TASK_COMPLETION_TIMEOUT_MS, [ref]$parsedTimeout) -and
        $parsedTimeout -gt 0) {
        $taskTimeoutMs = $parsedTimeout
    }

    $taskCmd = Get-Command task -ErrorAction SilentlyContinue
    $taskTempFile = $null
    $taskOutput = $null
    try {
        $taskTempFile = [System.IO.Path]::GetTempFileName()
        $taskProc = Start-Process -FilePath $taskCmd.Source `
            -ArgumentList '--completion', 'powershell' `
            -NoNewWindow -RedirectStandardOutput $taskTempFile -PassThru -ErrorAction Stop
        if ($taskProc.WaitForExit($taskTimeoutMs)) {
            $taskOutput = Get-Content $taskTempFile -Raw -ErrorAction SilentlyContinue
        } else {
            try { $taskProc.Kill() } catch { }
            Write-Host "`n(task completion init timed out after $([math]::Round($taskTimeoutMs / 1000, 1))s; skipping)" -ForegroundColor DarkYellow
        }
    } catch {
        Write-Host "(task completion init failed: $($_.Exception.Message))" -ForegroundColor DarkYellow
    } finally {
        if ($taskTempFile -and (Test-Path $taskTempFile -ErrorAction SilentlyContinue)) {
            Remove-Item $taskTempFile -ErrorAction SilentlyContinue
        }
    }
    if ($taskOutput) { Invoke-Expression $taskOutput }
}
