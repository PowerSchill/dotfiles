
# Move the start menu to the left of the screen
New-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force
New-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -PropertyType DWORD -Value 0
# Remove the Weather and News widget from the taskbar
New-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -PropertyType DWORD -Value 0
