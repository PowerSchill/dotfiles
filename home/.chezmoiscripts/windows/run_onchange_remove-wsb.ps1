# Only create the key when it is missing: New-Item -Force on an existing registry
# key replaces it, which deletes the other Windows Search policies stored there.
$windowsSearch = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $windowsSearch)) {
    New-Item $windowsSearch -Force | Out-Null
}
New-ItemProperty $windowsSearch -Name "EnableDynamicContentInWSB" -PropertyType DWORD -Value 0 -Force | Out-Null
