#!/bin/bash

# Arc
# defaults write company.thebrowser.Browser URLAllowlist -array-add 'omnifocus://*'
# defaults write company.thebrowser.Browser URLAllowlist -array-add 'x-devonthink-item://*'
# defaults write company.thebrowser.Browser ExternalProtocolDialogShowAlwaysOpenCheckbox -bool true

# Google Chrome
defaults write com.google.Chrome URLAllowlist -array-add 'omnifocus://*'
defaults write com.google.Chrome URLAllowlist -array-add 'x-devonthink-item://*'
defaults write com.google.Chrome ExternalProtocolDialogShowAlwaysOpenCheckbox -bool true
