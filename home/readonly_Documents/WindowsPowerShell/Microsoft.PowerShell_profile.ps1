$env:Path += ";$env:UserProfile\bin"
Set-Alias -Name g -Value git


oh-my-posh init pwsh --config ~/.oh-my-posh/powerlevel10k_rainbow.omp.json | Invoke-Expression
