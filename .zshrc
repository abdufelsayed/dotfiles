# ==============================================================================
# Powerlevel10k Instant Prompt (must stay at the top)
# ==============================================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
fi

# ==============================================================================
# Environment Variables
# ==============================================================================
export ZSH="$HOME/.oh-my-zsh"
export NVM_DIR="$HOME/.nvm"
export PNPM_HOME="/Users/abdllahdev/Library/pnpm"
export BUN_INSTALL="$HOME/.bun"
export PYENV_ROOT="$HOME/.pyenv"
export POETRY_PYTHON=$(pyenv which python)

# ==============================================================================
# PATH Configuration
# ==============================================================================
export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH="$PATH:/Users/abdllahdev/.local/bin"
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
export PATH="$BUN_INSTALL/bin:$PATH"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"

case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# opencode
export PATH=/Users/abdllahdev/.opencode/bin:$PATH

# Ghostty
export PATH="/Applications/Ghostty.app/Contents/MacOS:$PATH"

# ==============================================================================
# Oh-My-Zsh Configuration
# ==============================================================================
# Store completion cache in ~/.cache/zsh instead of home directory
export ZSH_COMPDUMP="$HOME/.cache/zsh/zcompdump-$HOST"

ZSH_THEME="powerlevel10k/powerlevel10k"
zstyle ':omz:update' mode auto

plugins=(
  git
  you-should-use
  zsh-syntax-highlighting
  zsh-completions
  zsh-autosuggestions
  colored-man-pages
)

source $ZSH/oh-my-zsh.sh

# ==============================================================================
# Znap Plugin Manager
# ==============================================================================
[[ -r ~/.local/share/zsh/znap/znap.zsh ]] ||
  git clone --depth 1 -- \
    https://github.com/marlonrichert/zsh-snap.git ~/.local/share/zsh/znap

source ~/.local/share/zsh/znap/znap.zsh
znap source marlonrichert/zsh-autocomplete

# ==============================================================================
# Tool Initializations
# ==============================================================================
# NVM
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Opam
eval $(opam env)

# Pyenv
eval "$(pyenv init -)"

# FZF
source <(fzf --zsh)

# Zoxide
eval "$(zoxide init --cmd cd zsh)"

# Julia
path=('/Users/abdllahdev/.juliaup/bin' $path)
export PATH

# ==============================================================================
# Completions
# ==============================================================================
# Bun completions
[ -s "/Users/abdllahdev/.bun/_bun" ] && source "/Users/abdllahdev/.bun/_bun"

# Google Cloud SDK
if [ -f '/Users/abdllahdev/.local/share/google-cloud-sdk/path.zsh.inc' ]; then
  . '/Users/abdllahdev/.local/share/google-cloud-sdk/path.zsh.inc'
fi

if [ -f '/Users/abdllahdev/.local/share/google-cloud-sdk/completion.zsh.inc' ]; then
  . '/Users/abdllahdev/.local/share/google-cloud-sdk/completion.zsh.inc'
fi

# ==============================================================================
# Aliases
# ==============================================================================
# eza (modern ls replacement)
if [ -x "$(command -v eza)" ]; then
  alias ls="eza"
  alias la="eza --long --all --group --icons --git"
  alias ll="eza --long --group --icons --git"
  alias llt="eza -2 --icons --tree --git-ignore"
fi

# FZF search with bat preview
alias search="fzf --preview 'bat --color=always --style=numbers --line-range=:499 {}' | xargs lvim"

# ==============================================================================
# Powerlevel10k Configuration (must stay at the bottom)
# ==============================================================================
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

. "$HOME/.local/share/../bin/env"

# Added by Antigravity
export PATH="/Users/abdllahdev/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity
export PATH="/Users/abdllahdev/.antigravity/antigravity/bin:$PATH"

# >>> forge initialize >>>
# !! Contents within this block are managed by 'forge zsh setup' !!
# !! Do not edit manually - changes will be overwritten !!

# Add required zsh plugins if not already present
if [[ ! " ${plugins[@]} " =~ " zsh-autosuggestions " ]]; then
    plugins+=(zsh-autosuggestions)
fi
if [[ ! " ${plugins[@]} " =~ " zsh-syntax-highlighting " ]]; then
    plugins+=(zsh-syntax-highlighting)
fi

# Load forge shell plugin (commands, completions, keybindings) if not already loaded
if [[ -z "$_FORGE_PLUGIN_LOADED" ]]; then
    eval "$(forge zsh plugin)"
fi

# Load forge shell theme (prompt with AI context) if not already loaded
if [[ -z "$_FORGE_THEME_LOADED" ]]; then
    eval "$(forge zsh theme)"
fi

# Editor for editing prompts (set during setup)
# To change: update FORGE_EDITOR or remove to use $EDITOR
export FORGE_EDITOR="code --wait"
# <<< forge initialize <<<
