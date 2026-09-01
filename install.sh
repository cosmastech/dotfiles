#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$DOTFILES/backups/$(date +%Y%m%d-%H%M%S)"
OH_MY_ZSH="${ZSH:-$HOME/.oh-my-zsh}"

log() { printf '==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }

backup_and_link() {
  local src="$1"
  local dest="$2"

  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    if [[ "$current" == "$src" ]]; then
      log "already linked $dest"
      return
    fi
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$BACKUP"
    mv "$dest" "$BACKUP/$(basename "$dest")"
    log "backed up $dest -> $BACKUP"
  fi

  ln -sfn "$src" "$dest"
  log "linked $dest -> $src"
}

ensure_oh_my_zsh() {
  if [[ -d "$OH_MY_ZSH" ]]; then
    log "oh-my-zsh already present"
    return
  fi
  log "installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

seed_local_stub() {
  local dest="$1"
  local contents="$2"
  if [[ -e "$dest" ]]; then
    return
  fi
  printf '%s\n' "$contents" >"$dest"
  chmod 600 "$dest"
  log "created $dest (not in git)"
}

install_brew_packages() {
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found; skipping brew update/bundle"
    return
  fi

  log "brew update"
  brew update

  # Existing /Applications apps sometimes fail "adopt" without sudo.
  # Missing packages are the real failure; we check those after.
  log "brew bundle --file=$DOTFILES/Brewfile"
  brew bundle --file="$DOTFILES/Brewfile" || warn "brew bundle reported errors (often sudo adopt on existing apps)"

  if grep -Eq '^(brew|cask) ' "$DOTFILES/Brewfile.work"; then
    log "brew bundle --file=$DOTFILES/Brewfile.work"
    brew bundle --file="$DOTFILES/Brewfile.work" || warn "Brewfile.work bundle reported errors"
  else
    log "Brewfile.work has no packages; skipping"
  fi

  for app in "Zed.app" "Spotify.app" "Hex.app" "Ghostty.app"; do
    if [[ -d "/Applications/$app" ]]; then
      log "found /Applications/$app"
    else
      warn "missing /Applications/$app"
    fi
  done
}

copy_hex_settings() {
  local src="$DOTFILES/hex/hex_settings.json"
  local dest="$HOME/Library/Containers/com.kitlangton.Hex/Data/Library/Application Support/com.kitlangton.Hex/hex_settings.json"

  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$BACKUP"
    cp -a "$dest" "$BACKUP/hex_settings.json"
    log "backed up $dest -> $BACKUP"
  fi
  # Copy, do not symlink: Hex runs sandboxed and rewrites this file.
  cp "$src" "$dest"
  log "copied Hex settings -> $dest"
}

install_skills() {
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills"
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
      npx --yes skills add "$source" --skill "$skill" -g -y \
        || warn "skills add failed or partially failed: $source $skill"
    else
      log "npx skills add $source"
      npx --yes skills add "$source" -g -y \
        || warn "skills add failed or partially failed: $source"
    fi
  done <"$DOTFILES/skills.txt"
}

merge_cursor_cli_config() {
  local src="$DOTFILES/cursor/cli-config.json"
  local dest="$HOME/.cursor/cli-config.json"

  mkdir -p "$(dirname "$dest")"

  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$BACKUP"
    cp -a "$dest" "$BACKUP/cli-config.json"
    log "backed up $dest -> $BACKUP"
  fi

  python3 - "$src" "$dest" "$HOME" <<'PY'
import json
import sys
from pathlib import Path

src, dest, home = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
repo = json.loads(src.read_text())
preserve_keys = (
    "privacyCache",
    "autoReviewAvailabilityCache",
    "serverConfigCache",
    "authInfo",
    "showSandboxIntro",
    "runEverythingSettingsPromptStreak",
)

live = {}
if dest.exists():
    live = json.loads(dest.read_text())

merged = dict(repo)
for key in preserve_keys:
    if key in live:
        merged[key] = live[key]

repo_allow = list(repo.get("permissions", {}).get("allow", []))
live_allow = list(live.get("permissions", {}).get("allow", []))
seen = set()
allow = []
for item in live_allow + repo_allow:
    if item not in seen:
        seen.add(item)
        allow.append(item)
merged.setdefault("permissions", {})["allow"] = allow
merged["permissions"]["deny"] = repo.get("permissions", {}).get("deny", live.get("permissions", {}).get("deny", []))

status = merged.get("statusLine") or {}
if status.get("type") == "command":
    status["command"] = f"/bin/bash {home}/.cursor/statusline.sh"
    merged["statusLine"] = status

dest.write_text(json.dumps(merged, indent=2) + "\n")
PY

  log "merged Cursor CLI config -> $dest (auth/cache kept local)"
}

doctor() {
  log "doctor"
  command -v brew >/dev/null && brew bundle check --file="$DOTFILES/Brewfile" || true
  printf '    ~/.zshrc -> %s\n' "$(readlink "$HOME/.zshrc" 2>/dev/null || echo '(not a symlink)')"
  printf '    ~/.cursor/cli-config.json model = %s\n' "$(python3 -c "import json,pathlib; print(json.loads(pathlib.Path.home().joinpath('.cursor/cli-config.json').read_text()).get('selectedModel',{}).get('modelId','?'))" 2>/dev/null || echo '(missing)')"
  printf '    node = %s  npx = %s\n' "$(command -v node || echo missing)" "$(command -v npx || echo missing)"
  printf '    git user.email (global) = %s\n' "$(git config --global user.email 2>/dev/null || echo '(unset)')"
  printf '    git user.name  (global) = %s\n' "$(git config --global user.name 2>/dev/null || echo '(unset)')"
}

ensure_oh_my_zsh

seed_local_stub "$HOME/.zshrc.local" "# Machine-specific zsh. Not committed."
seed_local_stub "$HOME/.zprofile.local" "# Machine-specific zprofile. Not committed."
seed_local_stub "$HOME/.gitconfig.local" "# Machine-specific git. Not committed.
# [user]
# 	email = you@work.example"

if [[ "${SKIP_BREW:-}" == "1" ]]; then
  log "SKIP_BREW=1; not touching Homebrew"
else
  install_brew_packages
fi

backup_and_link "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
backup_and_link "$DOTFILES/zsh/.zprofile" "$HOME/.zprofile"
backup_and_link "$DOTFILES/git/config" "$HOME/.gitconfig"
backup_and_link "$DOTFILES/zed/settings.json" "$HOME/.config/zed/settings.json"
backup_and_link "$DOTFILES/zed/keymap.json" "$HOME/.config/zed/keymap.json"
backup_and_link "$DOTFILES/ghostty/config" "$HOME/.config/ghostty/config"
backup_and_link "$DOTFILES/gh/config.yml" "$HOME/.config/gh/config.yml"
backup_and_link "$DOTFILES/cursor/statusline.sh" "$HOME/.cursor/statusline.sh"
copy_hex_settings
chmod +x "$HOME/.cursor/statusline.sh" "$DOTFILES/cursor/statusline.sh"
merge_cursor_cli_config

if [[ "${SKIP_SKILLS:-}" == "1" ]]; then
  log "SKIP_SKILLS=1; not touching npx skills"
else
  install_skills
fi
doctor

log "done"
if [[ -d "$BACKUP" ]]; then
  log "backups: $BACKUP"
fi
