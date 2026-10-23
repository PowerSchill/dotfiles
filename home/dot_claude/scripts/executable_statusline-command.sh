#!/usr/bin/env bash

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')
output_style=$(echo "$input" | jq -r '.output_style.name // ""')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Get current time
current_time=$(date +%H:%M:%S)

# Get git branch and status if in a git repo
git_info=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(
    git -c core.fileMode=false -c advice.detachedHead=false symbolic-ref --short HEAD 2>/dev/null || git -c core.fileMode=false -c advice.detachedHead=false rev-parse
    --short HEAD 2>/dev/null
  )

  # Check for changes (skip optional locks for performance)
  if ! git -c core.fileMode=false diff --quiet 2>/dev/null || ! git -c core.fileMode=false diff --cached --quiet 2>/dev/null; then
    git_status="*"
  else
    git_status=""
  fi

  if [ -n "$branch" ]; then
    git_info=" $(printf '\033[38;5;147m')  ${branch}${git_status}$(printf '\033[0m')"
  fi
fi

# Format directory path with colors (similar to P10k blue)
formatted_dir=$(printf '\033[1;38;5;117m')${cwd}$(printf '\033[0m')

# Build status line components
components=""

# Add time (similar to P10k style)
components="${components}$(printf '\033[38;5;247m')${current_time}$(printf '\033[0m') "

# Add directory
components="${components}${formatted_dir}"

# Add git info if available
components="${components}${git_info}"

# Add model info
components="${components} $(printf '\033[38;5;247m')│$(printf '\033[0m') $(printf '\033[38;5;150m')${model}$(printf '\033[0m')"

# Add output style if set and not default
if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
  components="${components} $(printf '\033[38;5;247m')[${output_style}]$(printf '\033[0m')"
fi

# Add context remaining if available
if [ -n "$remaining" ]; then
  # Color code based on remaining percentage
  if (($(echo "$remaining < 20" | bc -l 2>/dev/null || echo 0))); then
    color="203" # Red
  elif (($(echo "$remaining < 50" | bc -l 2>/dev/null || echo 0))); then
    color="221" # Yellow
  else
    color="150" # Green
  fi
  components="${components} $(printf "\033[38;5;${color}m")${remaining}%$(printf '\033[0m')"
fi

# Output the final status line
echo "$components"
