If ($PSversion.PSEditionTable -eq 'Desktop') {
    Write-Output "This script requires PowerShell version 6 or greater. AKA Not Windows PowerShell."
    Write Output "Execute this to download: winget install --id Microsoft.Powershell"

}
else {

    # Get the OS architecture
    $Architecture = [System.Environment]::OSVersion.Platform

    if ($Architecture -eq "Win32NT") {
        $OSArch = [System.Environment]::Is64BitOperatingSystem ? "x64" : "x86"

        Write-Debug "Detected Windows OS"
        Write-Host "OS Architecture: $OSArch"

        # Install required packages using winget
        winget install --id Git.Git -e --source winget
        winget install --id GitHub.cli -e --source winget
        winget install --id twpayne.chezmoi -e --source winget

        # TODO: Need to work around having to restart the console.

        # TODO: Need to automate the login process for GitHub CLI
        gh auth login


    } else {
        Write-Error "Unsupported OS architecture: $Architecture"
        Exit 1
    }
#
# # Restart terminal at this point
#
#
# # Initial setup until chezmoi takes over
#     git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
#
#
# # Run as administrator
#
#     Set-ExecutionPolicy RemoteSigned
#     chezmoi init --apply --verbose git@github.com:PowerSchill/dotfiles.git
#
#
# # Oh-My-Posh Setup
#     oh-my-posh font install meslo
#
}
