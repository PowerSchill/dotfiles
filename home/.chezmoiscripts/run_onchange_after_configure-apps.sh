#!/bin/bash

# GitHub CLI updates
if command -v gh &>/dev/null; then
  gh extension install github/gh-copilot
  gh extension install github/gh-dash
  gh extension install seachicken/gh-poi
fi
