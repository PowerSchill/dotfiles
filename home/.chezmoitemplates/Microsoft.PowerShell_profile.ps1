# This is my profile

# Set Path
if ( $IsMacOS ) {
    $Platform = (uname -m)

    switch ($Platform) {
        'arm64' {
           $Env:PATH += ":/opt/homebrew/bin" 
        }
    }
}


# Add local bin to PATH
$Env:PATH += ':~/bin'

# Run Oh-my-posh
oh-my-posh init pwsh --config ~/.oh-my-posh.json | Invoke-Expression
