$env:Path += ";$env:UserProfile\bin"
Set-Alias -Name g -Value git


oh-my-posh init pwsh | Invoke-Expression
