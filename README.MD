# Chezmoi Personal Configuration Management

## Requirements

### MacOS

```shell

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Setup shellenv
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install git
brew install git gh

# Install Chezmoi
brew install chezmoi

# Generate SSH Keys
echo ssh-keygen -t ed25519 -N "" -C "`whoami`@`hostname`" -f ~/.ssh/id_ed25519-q

# Authenticate GitHub CLI
gh auth login \
  --git-protocol ssh \
  --hostname github.com


```

