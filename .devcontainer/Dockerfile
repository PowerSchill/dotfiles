# syntax=docker/dockerfile:1
# Dev container image for this repo and for other projects (R18), published as
# ghcr.io/powerschill/dotfiles-dev by `mise run devcontainer:publish`.
#
#   user      vscode (so chezmoi treats it as an Ephemeral machine: dev Role)
#   shell     zsh with these dotfiles applied (configs and externals; no
#             run_ scripts, which install host packages via snap and cargo)
#   packages  the `base` apt bucket from home/.chezmoidata/packages.yaml
#   tools     mise and the minimal Toolchain; other projects add their own
#             mise.toml and run `mise install`
#
# Build context is the repo root: mise run devcontainer:build
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae

# zsh: check:zsh (a Toolchain system prerequisite). libatomic1: node, if a
# project's mise.toml asks for it. The base image strips /usr/share/doc, where
# Debian's fzf keeps the zsh key bindings the oh-my-zsh fzf plugin loads.
RUN echo 'path-include=/usr/share/doc/fzf/*' >/etc/dpkg/dpkg.cfg.d/zz-keep-fzf-shell \
  && apt-get update -qq \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends zsh libatomic1 \
  && rm -rf /var/lib/apt/lists/*

USER vscode
ENV PATH=/home/vscode/.local/bin:/home/vscode/.local/share/mise/shims:$PATH
COPY --chown=vscode:vscode . /home/vscode/.local/share/chezmoi
WORKDIR /home/vscode/.local/share/chezmoi

# The Toolchain, at the pinned versions. chezmoi (the provisioning tool) is also
# made the global default, so it works outside this directory too.
RUN DOTFILES_PROFILE=minimal tools/bootstrap.sh \
  && mise use -g "chezmoi@$(mise current chezmoi)"

# Base packages from packages.yaml, one at a time: a name missing from this
# Ubuntu release (fastfetch arrived in 24.10) is skipped, not fatal.
RUN sudo apt-get update -qq \
  && for p in $(mise x -- yq '.packages.linux.debian.packages.base[]' home/.chezmoidata/packages.yaml); do \
       sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$p" >/dev/null 2>&1 \
         || echo "devcontainer: skipped unavailable package $p"; \
     done \
  && sudo rm -rf /var/lib/apt/lists/*

# Apply the dotfiles as an Ephemeral machine. Scripts are excluded: they install
# host packages (snap, cargo, apt repos) that do not belong in an image.
RUN --mount=type=secret,id=github_token,uid=1000 \
  CHEZMOI_GITHUB_ACCESS_TOKEN="$(cat /run/secrets/github_token 2>/dev/null || true)" \
  mise x -- chezmoi init --apply --no-tty --source /home/vscode/.local/share/chezmoi \
    --exclude scripts \
  && mkdir -m 700 -p /home/vscode/.ssh \
  && sudo chsh -s /usr/bin/zsh vscode

WORKDIR /workspaces
CMD ["zsh", "-l"]
