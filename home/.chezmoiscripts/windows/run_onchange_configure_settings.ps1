# Only create the key when it is missing: New-Item -Force on an existing registry
# key replaces it, which deletes every other Explorer setting stored there.
$advanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (-not (Test-Path $advanced)) {
    New-Item $advanced -Force | Out-Null
}

# Move the start menu to the left of the screen
New-ItemProperty $advanced -Name "TaskbarAl" -PropertyType DWORD -Value 0 -Force | Out-Null
# Remove the Weather and News widget from the taskbar
New-ItemProperty $advanced -Name "TaskbarDa" -PropertyType DWORD -Value 0 -Force | Out-Null
