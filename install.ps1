# winget install --id Microsoft.Powershell

# https://github.com/PowerShell/PowerShell/releases/download/v7.4.5/PowerShell-7.4.5-win-arm64.zip



winget install Git.Git
winget install twpayne.chezmoi
winget install --id GitHub.cli
winget install dandavison.delta
winget install AgileBits.1Password
winget install AgileBits.1Password.CLI


# Restart terminal at this point


# Initial setup until chezmoi takes over
git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"


# Run as administrator

Set-ExecutionPolicy RemoteSigned
chezmoi init --apply --verbose git@github.com:PowerSchill/dotfiles.git


# Oh-My-Posh Setup
oh-my-posh font install meslo
