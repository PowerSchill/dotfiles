# This is my profile

# Set Path
if ( $IsMacOS ) {
    $Platform = (uname -m)
    
    $(/usr/local/bin/brew shellenv) | Invoke-Expression

    switch ($Platform) {
        'arm64' {
        }
    }
}


# Add local bin to PATH
$Env:PATH += ':~/bin'

# Run Oh-my-posh
oh-my-posh init pwsh --config ~/.oh-my-posh.json | Invoke-Expression
