#!/usr/bin/env bash
# Install or refresh the skills listed in skills.txt.
# Run on its own: ~/.dotfiles/install-skills.sh
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

log() { printf '==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }

install_skills() {
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills"
    return
  fi

  if [[ ! -f "$DOTFILES/skills.txt" ]]; then
    warn "missing $DOTFILES/skills.txt"
    return
  fi

  local line source skill
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z "$line" ]] && continue

    source="${line%% *}"
    skill="${line#"$source"}"
    skill="$(printf '%s' "$skill" | sed -e 's/^[[:space:]]*//')"

    if [[ -n "$skill" ]]; then
      log "npx skills add $source --skill $skill"
      # skills reads stdin; keep it off the skills.txt loop
      npx --yes skills add "$source" --skill "$skill" -g -y </dev/null \
        || warn "skills add failed or partially failed: $source $skill"
    else
      log "npx skills add $source"
      npx --yes skills add "$source" -g -y </dev/null \
        || warn "skills add failed or partially failed: $source"
    fi
  done <"$DOTFILES/skills.txt"
}

install_skills
