# syntax=docker/dockerfile:1
# Dev container image for this repo and for other projects (R18), published as
# ghcr.io/powerschill/dotfiles-dev by `mise run devcontainer:publish`.
#
#   user      vscode (so chezmoi treats it as an Ephemeral machine: dev Role)
#   shell     zsh with these dotfiles applied (configs and externals; no
#             run_ scripts, which provision a whole host)
#   packages  the `base` Homebrew bucket from home/.chezmoidata/packages.yaml,
#             after the native prerequisites Homebrew needs
#   tools     mise and the minimal Toolchain; other projects add their own
#             mise.toml and run `mise install`
#
# Build context is the repo root: mise run devcontainer:build
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae

# zsh: check:zsh (a Toolchain system prerequisite). libatomic1: node, if a
# project's mise.toml asks for it.
RUN apt-get update -qq \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends zsh libatomic1 \
  && rm -rf /var/lib/apt/lists/*

USER vscode
ENV PATH=/home/vscode/.local/bin:/home/vscode/.local/share/mise/shims:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH
COPY --chown=vscode:vscode . /home/vscode/.local/share/chezmoi
WORKDIR /home/vscode/.local/share/chezmoi

# The Toolchain, at the pinned versions. chezmoi (the provisioning tool) is also
# made the global default, so it works outside this directory too.
RUN DOTFILES_PROFILE=minimal tools/bootstrap.sh \
  && mise use -g "chezmoi@$(mise current chezmoi)"

# What Homebrew needs, from the native list in packages.yaml.
RUN sudo apt-get update -qq \
  && mise x -- yq '.packages.linux.debian.packages.base[]' home/.chezmoidata/packages.yaml \
    | xargs sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
  && sudo rm -rf /var/lib/apt/lists/*

# Apply the dotfiles as an Ephemeral machine. Scripts are excluded: they provision
# a whole host, which does not belong in an image. Then install only the `base`
# bucket through Homebrew, so the image stays smaller than a dev Machine.
RUN --mount=type=secret,id=github_token,uid=1000 \
  CHEZMOI_GITHUB_ACCESS_TOKEN="$(cat /run/secrets/github_token 2>/dev/null || true)" \
  mise x -- chezmoi init --apply --no-tty --source /home/vscode/.local/share/chezmoi \
    --exclude scripts \
  && mkdir -m 700 -p /home/vscode/.ssh \
  && sudo chsh -s /usr/bin/zsh vscode \
  && bash -c '. home/dot_config/shell/functions/log.sh \
    && . home/dot_config/shell/functions/homebrew.sh \
    && homebrew_prepare' \
  && mise x -- chezmoi execute-template --source /home/vscode/.local/share/chezmoi \
    '{{ $d := deepCopy . }}{{ $_ := set $d "roles" list }}{{ template "brewfile.tmpl" $d }}' >/home/vscode/.Brewfile \
  && HOMEBREW_NO_ANALYTICS=1 brew bundle --file=/home/vscode/.Brewfile \
  && rm -rf "$(brew --cache)"

WORKDIR /workspaces
CMD ["zsh", "-l"]
