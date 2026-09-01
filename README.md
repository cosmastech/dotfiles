# dotfiles

Personal macOS bootstrap. Clone to `~/.dotfiles` and run `./install.sh`.

Inspired by [dmmulroy/.dotfiles](https://github.com/dmmulroy/.dotfiles) (Brewfile split, one install verb) without the 2,500-line `dot` CLI.

## What it does

- `brew update` and `brew bundle` (does **not** `brew upgrade`)
- Symlinks zsh, git, Zed, Ghostty, `gh`, and Cursor statusline
- Copies Hex settings (sandbox cannot follow a symlink)
- Merges portable Cursor agent CLI prefs into `~/.cursor/cli-config.json` (auth/cache stay on the machine)
- Installs a short list of agent skills via `npx skills` (`brew node` provides `npx`)

Machine-specific and secret config lives in untracked files:

- `~/.zshrc.local`
- `~/.zprofile.local`
- `~/.gitconfig.local`

## Install

```bash
git clone https://github.com/cosmastech/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

Existing files are moved to `~/.dotfiles/backups/<timestamp>/` before they are replaced with symlinks.

## Layout

```
Brewfile            # shared packages
Brewfile.work       # optional work-only packages (empty hook)
zsh/.zshrc
zsh/.zprofile
git/config
zed/settings.json
zed/keymap.json
ghostty/config
gh/config.yml
hex/hex_settings.json
cursor/cli-config.json   # portable agent CLI prefs (no auth)
cursor/statusline.sh
skills.txt          # npx skills sources
install.sh
```

## Docs

- [v1 plan](docs/PLAN.md)
- [Personal machine inventory handoff](docs/PERSONAL-MACHINE-HANDOFF.md)
