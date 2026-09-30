#!/usr/bin/env bash
# Install or refresh the skills listed in skills.txt.
# Run on its own: ~/.dotfiles/install-skills.sh
# Relocate skills that are already installed: ~/.dotfiles/install-skills.sh --publish-only
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
AGENTS_SKILLS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
CURSOR_SKILLS_DIR="${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}"

log() { printf '==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }

# Print "source<TAB>skill" for each skills.txt entry. The skill field may be empty.
each_skill_spec() {
  local line source skill
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z "$line" ]] && continue

    source="${line%% *}"
    skill="${line#"$source"}"
    skill="$(printf '%s' "$skill" | sed -e 's/^[[:space:]]*//')"
    printf '%s\t%s\n' "$source" "$skill"
  done <"$DOTFILES/skills.txt"
}

# Second field is the installed folder name. A bare source uses its last path segment.
skill_folder_name() {
  local source="$1" skill="$2"
  if [[ -n "$skill" ]]; then
    printf '%s\n' "$skill"
  else
    basename "$source"
  fi
}

# skills reads stdin; keep it off the skills.txt loop.
add_skill() {
  local source="$1" skill="$2"
  if [[ -n "$skill" ]]; then
    log "npx skills add $source --skill $skill"
    npx --yes skills add "$source" --skill "$skill" -g -y </dev/null
  else
    log "npx skills add $source"
    npx --yes skills add "$source" -g -y </dev/null
  fi
}

install_skills() {
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills"
    return
  fi

  if [[ ! -f "$DOTFILES/skills.txt" ]]; then
    warn "missing $DOTFILES/skills.txt"
    return
  fi

  local source skill
  while IFS=$'\t' read -r source skill; do
    add_skill "$source" "$skill" \
      || warn "skills add failed or partially failed: $source $skill"
  done < <(each_skill_spec)
}

# Cursor cloud sync reads real directories in ~/.cursor/skills and skips symlinks.
# npx skills keeps the real folder in ~/.agents/skills, so move that folder into
# ~/.cursor/skills and point ~/.agents/skills/<name> back at it.
publish_one_cursor_skill() {
  local name="$1"
  local backup_root="$2"
  local source="$3"
  local skill="$4"
  local agents="$AGENTS_SKILLS_DIR/$name"
  local cursor="$CURSOR_SKILLS_DIR/$name"
  local agents_real cursor_real

  if [[ -L "$agents" && -d "$cursor" && ! -L "$cursor" ]]; then
    if agents_real="$(cd "$agents" && pwd -P)" \
      && cursor_real="$(cd "$cursor" && pwd -P)" \
      && [[ "$agents_real" == "$cursor_real" ]]; then
      log "already in $CURSOR_SKILLS_DIR: $name"
      return 0
    fi
  fi

  if [[ -L "$agents" ]]; then
    if [[ -d "$agents" ]]; then
      warn "skipping $name; $agents is a symlink to $(readlink "$agents")"
      return 0
    fi
    # The only copy lived in ~/.cursor/skills and is gone. Fetch it again,
    # then the move below puts a real directory back for cloud agents.
    log "reinstalling $name; $agents points at a missing directory"
    if ! command -v npx >/dev/null 2>&1; then
      warn "npx not found; cannot reinstall $name"
      return 0
    fi
    add_skill "$source" "$skill" || {
      warn "reinstall failed: $source $skill"
      return 0
    }
  fi

  if [[ ! -d "$agents" ]]; then
    if [[ -d "$cursor" && ! -L "$cursor" ]]; then
      mkdir -p "$AGENTS_SKILLS_DIR"
      ln -sfn "$cursor" "$agents"
      log "linked $agents -> $cursor"
      return 0
    fi
    warn "skipping $name; not installed at $agents"
    return 0
  fi

  mkdir -p "$CURSOR_SKILLS_DIR"

  if [[ -L "$cursor" ]]; then
    rm "$cursor"
  elif [[ -e "$cursor" ]]; then
    local dest="$backup_root/cursor-skill-$name"
    mkdir -p "$backup_root"
    if [[ -e "$dest" ]]; then
      dest="$backup_root/cursor-skill-$name-$$"
    fi
    mv "$cursor" "$dest"
    log "backed up $cursor -> $dest"
  fi

  mv "$agents" "$cursor" || {
    warn "failed to move $agents -> $cursor"
    return 0
  }
  ln -sfn "$cursor" "$agents"
  log "moved $name -> $cursor"
}

publish_cursor_skills() {
  if [[ ! -f "$DOTFILES/skills.txt" ]]; then
    warn "missing $DOTFILES/skills.txt"
    return
  fi

  local backup_root="$DOTFILES/backups/$(date +%Y%m%d-%H%M%S)"
  local source skill name
  while IFS=$'\t' read -r source skill; do
    name="$(skill_folder_name "$source" "$skill")"
    publish_one_cursor_skill "$name" "$backup_root" "$source" "$skill"
  done < <(each_skill_spec)
}

publish_only=0
if [[ $# -gt 1 ]]; then
  warn "usage: $0 [--publish-only]"
  exit 1
fi
if [[ "${1:-}" == "--publish-only" ]]; then
  publish_only=1
elif [[ -n "${1:-}" ]]; then
  warn "usage: $0 [--publish-only]"
  exit 1
fi

if [[ "$publish_only" -eq 0 ]]; then
  install_skills
fi

if [[ "${SKIP_CURSOR_SKILLS:-}" == "1" ]]; then
  log "SKIP_CURSOR_SKILLS=1; leaving skill folders in $AGENTS_SKILLS_DIR"
else
  publish_cursor_skills
fi
