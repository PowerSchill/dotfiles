winget install twpayne.chezmoi
winget install --id GitHub.cli
winget install Git.Git
winget install AgileBits.1Password
winget install AgileBits.1Password.CLI


Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
chezmoi init --apply --verbose git@github.com:PowerSchill/dotfiles.git
