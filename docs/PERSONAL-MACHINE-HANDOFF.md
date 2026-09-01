# Personal machine inventory handoff

Read this whole file before you touch anything. You are on Luke Kuzmish’s **personal** Mac. Your job is to **inventory** and **report**. You are not here to make this machine look like the work laptop.

## Who / what

- Human: Luke (`cosmastech` on GitHub, email `lakuzmish@gmail.com`)
- Work laptop already has a v1 repo: `https://github.com/cosmastech/dotfiles` cloned at `~/.dotfiles`
- This document lives in that repo at `docs/PERSONAL-MACHINE-HANDOFF.md`
- Work machine is a Loop Returns laptop (PHP/Herd/GitLab). New job is TypeScript. Personal is expected to have the more interesting setup.

## Goal

Produce a written report of **neat, reusable, non-secret** config on the personal machine that is **not already in v1**. Luke will decide what to fold into `cosmastech/dotfiles`. You do not fold it in.

## Hard rules

1. **Do not run `~/.dotfiles/install.sh`.** Do not symlink, do not `brew bundle`, do not overwrite `~/.zshrc` / gitconfig / Zed / `~/.cursor/cli-config.json`.
2. **Do not create a competing dotfiles repo** unless Luke explicitly asks in that session.
3. **Do not print, copy, or commit secrets.** If you see tokens, PATs, `.env`, SSH keys, 1Password leftovers, cookie dumps, or `export SOMETHING=sk-…` / `glpat-` / `ddpat_` / `ghp_`, say “secret present in `<path>` (redacted)” and move on.
4. **Do not push to `cosmastech/dotfiles` from this machine.**
5. Read-only except for a scratch file you may write at `/tmp/dotfiles-personal-inventory.md` if you want a place to draft the report.

If the public repo is not cloned here, read this file from GitHub. You still do not install it.

## What v1 already covers (do not “discover” these as new)

Already decided / already in the work repo:

| Area | v1 |
|---|---|
| Layout | `install.sh`, `Brewfile`, empty `Brewfile.work`, `ln -sfn` (no Stow) |
| Git | `Luke Kuzmish` / `lakuzmish@gmail.com`, `push.autoSetupRemote`, `rerere`; machine overrides in `~/.gitconfig.local` |
| Shell | Oh My Zsh (`robbyrussell`, `git` plugin), nvm, `~/.local/bin`, `source ~/.zshrc.local` |
| Apps | `gh`, `zed`, `spotify`, `kitlangton-hex`, `ghostty`, Geist Mono, `node` |
| Zed | JetBrains keymap, format_on_save off, system theme, One Light / One Dark, agent dock right |
| Ghostty | Geist Mono 16 |
| Hex | Right Option hotkey, Shift-Option-V paste last, Parakeet model |
| gh | `git_protocol: ssh`, `co` → `pr checkout`. Hosts/auth stay local. |
| Skills | `cosmastech/skills` → `planning-conventions`, `multi-model-code-review`; `dmmulroy/.dotfiles` → `bro`; `mattpocock/skills` → `grill-with-docs` (+ `grilling`, `domain-modeling`) |
| Cursor CLI | zen display, thinking blocks, max mode, Grok 4.6 default, `approvalMode: unrestricted`, custom `statusline.sh`, attribution off. Auth/team caches and Loop MCP allowlist are **not** in the repo. |

Work-laptop-only (must **not** be recommended for the public repo unless Luke says so):

- Herd, herd-lite, PhpStorm PATH, Snowflake CLI, OrbStack init
- `loop` / `loopsh` / `loopup` aliases, `BRAG_HOME`
- Anything from `git@gitlab.com:loopreturns/skills/odyssey-skills`
- Datadog / GitLab tokens

## What “interesting” means

Flag it if it is portable and Luke would want it on a third Mac:

- Extra Homebrew formulae/casks that are not work-only (Ghostty, Raycast, 1Password, fonts, ripgrep, fzf, etc.)
- A real zshrc: aliases, functions, prompt (Starship/Pure), completions — not just OMZ defaults
- Editor config beyond Zed defaults: Cursor, Neovim, VS Code, JetBrains ideavim, Helix
- Terminal: Ghostty, Kitty, WezTerm, iTerm profiles that are files (not just GUI prefs)
- Git extras: aliases, signing, delta, lazygit
- Window / input tools besides Hex
- Public agent skills with a provenance file (see below)
- A **pre-existing personal dotfiles repo** (this is the jackpot — compare it to v1, do not merge)

Skip: caches, `node_modules`, Histories, iCloud junk, screenshots, chat logs.

## Provenance: how to find where a skill came from

On the work laptop, `bro` was mystery meat until `~/.agents/.skill-lock.json`:

```json
"bro": {
  "source": "dmmulroy/.dotfiles",
  "sourceType": "github",
  "sourceUrl": "https://github.com/dmmulroy/.dotfiles.git",
  "skillPath": "home/.agents/skills/bro/SKILL.md"
}
```

Check these, in order, on the personal machine:

1. `~/.agents/.skill-lock.json` (and any `skills-lock.json` / `.skills.json`)
2. `~/.claude/.skill-lock.json`, `~/.codex/`, `~/.cursor/`
3. Frontmatter in each `SKILL.md` (homepage, source, author)
4. `npx skills list` if the CLI is available

Work laptop already has these **public** skills (candidates to mention if personal has them too, or has more from the same repos):

| Skill | Source |
|---|---|
| planning-conventions | `cosmastech/skills` (already in v1) |
| multi-model-code-review | `cosmastech/skills` (already in v1) |
| multi-model-planning | `cosmastech/skills` |
| laravel-conventions | `cosmastech/skills` (PHP — probably skip for TS life) |
| php-conventions | `cosmastech/skills` (skip) |
| adhd | `cosmastech/skills` |
| grill-me | `mattpocock/skills` |
| improve-codebase-architecture | `mattpocock/skills` |
| bro | `dmmulroy/.dotfiles` (already in v1) |
| brag-capture / brag-review | `cosmastech/brags` |
| herdr | `ogulcancelik/herdr` |
| glab | `henricook/claude-glab-skill` (GitLab — work-ish) |

Do not list Odyssey/Loop skills as “add to public dotfiles.”

## Commands to run (read-only)

```bash
# Homebrew
brew --prefix
brew list --formula
brew list --cask
test -f ~/Brewfile && echo "HAS ~/Brewfile"

# Shell
ls -la ~/.zshrc ~/.zprofile ~/.zshenv ~/.zlogin 2>/dev/null
wc -l ~/.zshrc ~/.zprofile 2>/dev/null
# Print zshrc/zprofile for review, then redact secrets in the report

# Git
git config --global --list
ls -la ~/.gitconfig ~/.gitconfig.local ~/.config/git 2>/dev/null

# Editors / terminal
ls -la ~/.config/zed ~/.config/nvim ~/.config/ghostty ~/.config/kitty ~/.config/wezterm ~/.config/helix 2>/dev/null
ls -la ~/Library/Application\ Support/Cursor/User 2>/dev/null
ls /Applications | sed -n '1,200p'

# Skills
ls ~/.agents/skills ~/.claude/skills ~/.codex 2>/dev/null
test -f ~/.agents/.skill-lock.json && python3 -c "
import json
d=json.load(open('$HOME/.agents/.skill-lock.json'))
skills=d.get('skills', d)
for k,v in skills.items():
    if not isinstance(v, dict): continue
    print(f\"{k}\t{v.get('source','?')}\t{v.get('skillPath','')}\")
"

# Existing dotfiles?
ls -la ~/.dotfiles ~/dotfiles ~/projects/dotfiles 2>/dev/null
gh repo list cosmastech --limit 50 2>/dev/null

# Cursor agent CLI (redact authInfo / *Cache in the report)
ls -la ~/.cursor/cli-config.json ~/.cursor/statusline.sh 2>/dev/null
```

Compare `/Applications` and `brew list --cask` against v1: `gh`, Zed, Spotify, Hex.

## Report format (return this to Luke)

```markdown
# Personal machine inventory

## Existing dotfiles?
- [ ] none / [ ] path / [ ] github url

## Apps / brew worth stealing
- name — why it is portable

## Shell
- what is non-default in zshrc (no secrets)
- prompt / plugins

## Editors
- Zed diffs vs work (JetBrains keymap, format_on_save off, One Light/Dark)
- anything else (nvim, Cursor user settings)

## Skills
- name — source URL — recommend for public repo? (yes/no + why)

## Git
- aliases, signing, delta, other

## Do not import
- secrets locations (paths only)
- work-only / PHP / Loop stuff

## Recommended next adds to cosmastech/dotfiles
1. …
2. …
```

Be opinionated. “Here is a dump of `ls`” is not a report. “Steal Ghostty + Starship; skip the Laravel aliases” is a report.
