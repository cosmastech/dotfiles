# Dotfiles v1 plan

## TL;DR

Boring bootstrap at `~/.dotfiles`, public as `cosmastech/dotfiles`. One `install.sh`: `brew update` + `brew bundle`, symlink configs, install a short skills list via `npx skills`. Secrets and Loop/PHP leftovers stay in untracked `*.local` files. This work laptop keeps `lukekuzmish@loopreturns.com` via `~/.gitconfig.local` so Loop commits do not change. Personal machine is inventory-only until we read the handoff report.

## Decisions

| Topic | Choice |
|---|---|
| Shape | Option 2: `install.sh` + `ln -sfn`, no Stow, no Dillon `dot` CLI |
| Work hook | `Brewfile.work` exists; empty today |
| Git identity (repo) | Luke Kuzmish / `lakuzmish@gmail.com` |
| Git identity (this laptop) | email overridden in `~/.gitconfig.local` |
| Remote | public `cosmastech/dotfiles` |
| Path | `~/.dotfiles` |
| Shell | Oh My Zsh + nvm in public zshrc; Loop/Herd/PhpStorm/Snowflake/tokens in `.zshrc.local` |
| Apps | `gh`, `zed`, `spotify`, `kitlangton-hex`, `ghostty`, Geist Mono, `node` (for `npx`) |
| Skills | `planning-conventions`, `multi-model-code-review`, `bro`, `grill-with-docs` (+ `grilling`, `domain-modeling`) |
| Cursor CLI | Portable prefs + statusline in repo; merge into live `cli-config.json`; strip auth/team caches and Loop MCP allows from git |
| Apply on work laptop | Yes, with backups. No `brew upgrade`. |

## Failure scenarios

| Failure | Recovery | Communicate |
|---|---|---|
| Symlink replaces a real file | Copy sits in `~/.dotfiles/backups/<timestamp>/` | `install.sh` prints backup path |
| Loop commits pick up Gmail | `~/.gitconfig.local` overrides email; `git config user.email` in a Loop repo should still be work | Verify after apply |
| `brew bundle` fights a DMG-installed Hex/Zed/Spotify | Adopt can fail without sudo `chmod`; apps stay; install continues | Check `/Applications`; do not `brew upgrade` |
| Skill install fails | Other steps already done; rerun `npx skills add …` | Print the failed source |
| Token lands in git | `.gitignore` + pre-push audit of staged files | Never copy `*.local` into the repo |
| Cursor CLI symlink would write Auth0/team cache into git | Merge, do not symlink `cli-config.json` | Live file keeps `authInfo` / `*Cache` |
| Public zshrc is missing a PATH this laptop needs | That PATH belongs in `.zshrc.local`; restore from backup if a session breaks | Open a new terminal and check |

## Observability

After `./install.sh`:

- `readlink ~/.zshrc` → `~/.dotfiles/zsh/.zshrc`
- `git config --global user.email` on this laptop → work email (local override)
- `brew bundle check --file ~/.dotfiles/Brewfile`
- `npx skills list` shows the three v1 skills
- A new interactive zsh sources without errors

No monitors. This is a laptop bootstrap, not a service.

## Out of scope

- Stow / Chezmoi / Nix
- `brew upgrade` of the world
- Vendoring Loop / Odyssey skills
- Applying this repo on the personal machine (inventory first: `docs/PERSONAL-MACHINE-HANDOFF.md`)
