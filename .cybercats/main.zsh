export PATH="$PATH:/snap/bin"
CC_SAFE_MODE=false

for arg in "$@"; do
  [[ "$arg" == "--safemode" ]] && CC_SAFE_MODE=true
done

export CC_DEFAULTS="$CC_ROOT/defaults"



# Load env vars
IFS="="
while read cc_defaults; do
  read -r env_var value <<< $cc_defaults
  if [[ -n "$env_var" && -n "$value" ]]; then
    export $env_var=${(e)value}
  fi
done < $CC_DEFAULTS
unset IFS

# Load Cybercat Essentials (our other ready made zsh files)
source $ZSH_PALETTE_PATH
source $ZSH_ALIAS_PATH

# Load keybinds
while read keybinds; do
  read -r key action <<< $keybinds
  bindkey "$key" "$action"
done < $ZSH_KEYBIND_PATH

# Load Powers
for power in "$CC_ROOT"/powers/builtins/*.zsh; do
  source "$power"
done

if [[ "$CC_SAFE_MODE" != true ]]; then
  for power in "$CC_ROOT"/powers/installed/*.zsh(N); do
    source "$power"
  done
fi

# History Configuarionts
power_dir $(dirname "$ZSH_HISTORY_FILE_PATH")
touch $ZSH_HISTORY_FILE_PATH

HISTSIZE=1000
SAVEHIST=1000
HISTFILE=$ZSH_HISTORY_FILE_PATH
alias edit_hist="$CC_TEXT_EDITOR $ZSH_HISTORY_FILE_PATH"
setopt histignorealldups sharehistory

# Auto-complete configurations
autoload -Uz compinit
compinit
source "$ZSH_VISUAL_CONFIG_DIR/compinit_style.zsh"

# Thor Powers
tmux_quick_vertical() {
  if [[ -n "$TMUX" ]]; then
    tmux split-window -h
  else
    tmux new-session \; split-window -h
  fi
}


# External Goodies
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Starship Config
eval "$(starship init zsh)"
source "$ZSH_VISUAL_CONFIG_DIR/render_cc_header.zsh"
render_cc_header


