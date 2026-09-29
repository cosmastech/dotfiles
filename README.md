# dotfiles

Personal macOS bootstrap. Clone to `~/.dotfiles` and run `./install.sh`.

Inspired by [dmmulroy/.dotfiles](https://github.com/dmmulroy/.dotfiles) (Brewfile split, one install verb) without the 2,500-line `dot` CLI.

## What it does

- `brew update` and `brew bundle --no-upgrade`
- Writes `~/.zshrc` / `.zshenv` / `.zprofile` stubs that source the repo (so installers do not write into git)
- Writes a `~/.gitconfig` stub that includes the repo (so `git config --global` does not write into git)
- Symlinks Zed, Ghostty, and `gh`
- Copies Hex settings (sandbox cannot follow a symlink)
- Merges portable VS Code settings into Cursor (and VS Code if installed). Extra live keys stay on the machine
- Merges portable Cursor agent CLI prefs into `~/.cursor/cli-config.json` (auth/cache stay on the machine)
- Installs the Cursor agent CLI with the official installer
- Installs a short list of agent skills via `npx skills` (`brew node` provides `npx`), then moves each listed skill into `~/.cursor/skills` so Cursor cloud agents can sync it. Refresh that list on its own with `./install-skills.sh`
- Installs Plannotator and its optional skills with the official installer

Machine-specific and secret config lives in untracked files:

- `~/.zshrc.local`
- `~/.zshenv.local`
- `~/.zprofile.local`
- `~/.gitconfig.local`

## Install

```bash
git clone https://github.com/cosmastech/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

Existing files are moved to `~/.dotfiles/backups/<timestamp>/` before they are replaced.

Set `SKIP_BREW=1`, `SKIP_SKILLS=1`, `SKIP_PLANNOTATOR=1`, or `SKIP_CURSOR_CLI=1` to omit that part of an install. `SKIP_CURSOR_SKILLS=1` still installs skills and leaves the real folders in `~/.agents/skills`.

Refresh skills without the rest of the bootstrap:

```bash
~/.dotfiles/install-skills.sh
```

`npx skills` stores the real folder in `~/.agents/skills/<name>` and symlinks that into other agent directories. Cursor cloud sync reads `~/.cursor/skills` and skips symlinks, so those skills never upload. After each install, `install-skills.sh` moves the listed skill folders into `~/.cursor/skills/<name>` and points `~/.agents/skills/<name>` back at them. Local agents still open the skill through `~/.agents/skills`. An existing real folder already at `~/.cursor/skills/<name>` is moved to `~/.dotfiles/backups/<timestamp>/` first. After the first move, toggle Cursor cloud agent skill sync off and back on so it picks up the real directories.

Skills already on disk can be relocated without fetching again:

```bash
~/.dotfiles/install-skills.sh --publish-only
```

Only names in `skills.txt` are moved. Other folders in `~/.agents/skills` stay where they are.

## Layout

```
Brewfile            # shared packages
Brewfile.work       # optional work-only packages (empty hook)
zsh/.zshrc
zsh/.zshenv
zsh/.zprofile
git/config
zed/settings.json
zed/keymap.json
ghostty/config
gh/config.yml
hex/hex_settings.json
vscode/settings.json     # shared Cursor + VS Code defaults (no Cursor-only keys)
cursor/cli-config.json   # portable agent CLI prefs (no auth)
skills.txt          # npx skills sources
install.sh
install-skills.sh   # npx skills from skills.txt, then real folders in ~/.cursor/skills
```

## Docs

- [v1 plan](docs/PLAN.md)
- [Personal machine inventory handoff](docs/PERSONAL-MACHINE-HANDOFF.md)
