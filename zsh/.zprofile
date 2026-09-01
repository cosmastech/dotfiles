eval "$(/opt/homebrew/bin/brew shellenv)"

export PATH="$HOME/.local/bin:$PATH"

[[ -f "$HOME/.zprofile.local" ]] && source "$HOME/.zprofile.local"
