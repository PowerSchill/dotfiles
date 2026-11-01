# PowerShell Aliases
# Loaded by profile.ps1

# Navigation
Set-Alias -Name .. -Value Set-LocationUp
Set-Alias -Name ... -Value Set-LocationUpUp

# List files (Unix-like)
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force @args }

# Git shortcuts
function git { Invoke-GitWithCredentialSwitch @args }
function g { git @args }
function gs { git status @args }
function ga { git add @args }
function gc { git commit @args }
function gps { git push @args }
function gpl { git pull @args }
function gl { git log --oneline --graph @args }
function gd { git diff @args }
function gco { git checkout @args }
function gb { git branch @args }

# Docker shortcuts
function d { docker @args }
function dc { docker compose @args }
function dps { docker ps @args }
function dpsa { docker ps -a @args }
function di { docker images @args }
function dex { docker exec -it @args }

# Profile management
Set-Alias -Name ep -Value Edit-Profile
Set-Alias -Name reload -Value Import-Profile

# Shell introspection
Set-Alias -Name aliases -Value Show-Aliases
function functions { Get-Command -CommandType Function | Where-Object { $_.Source -eq '' } | Select-Object -ExpandProperty Name }
function paths { $env:PATH -split [IO.Path]::PathSeparator }

# System info
function ff { fastfetch @args }
function sysinfo { fastfetch @args }
function motd { fastfetch @args }

# SSH
function pubkey { Get-Content ~/.ssh/id_rsa.pub | Set-Clipboard; Write-Host '=> Public key copied to clipboard.' }
Set-Alias -Name copilot-ssh -Value Connect-CopilotSsh
Set-Alias -Name copilot_ssh -Value Connect-CopilotSsh

# Chezmoi shortcuts
Set-Alias -Name chezmoi-up -Value Update-Chezmoi
Set-Alias -Name chezmoi_up -Value Update-Chezmoi
Set-Alias -Name czu -Value Update-Chezmoi

# Winget shortcuts
Set-Alias -Name wup -Value Invoke-WingetUpgrade
Set-Alias -Name winup -Value Invoke-WingetUpgrade

# Help (keeping backward compatibility)
