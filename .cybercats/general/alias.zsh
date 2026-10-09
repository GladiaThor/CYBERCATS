# Window Mgmt Aliases
alias vsplit=tmux_quick_vertical
alias qvs=vsplit #Yes I am just this lazy

# Custom Command Aliases
alias gstat="git status"
alias markln="source $MARKLN_DIR/.venv/bin/activate && py $MARKLN_DIR/markln.py && deactivate"
alias zsh_path_conf="nvim $ZSH_PATHS_PATH"
alias configure_zsh="nvim .zshrc && exec zsh"
alias pbcopy='xclip -sel clip'
alias pbpaste='xclip -sel clip -o'
alias pwdcopy="pwd | tr -d '\n' | pbcopy && echo ' Current pwd copied to clipboard!'"

# Task Aliases
alias qtask='task add due:monday priority:M'

# Application Aliases
alias py=python3
alias pip=pip3
alias python=python3
alias obsidian="tqs "obsidian" flatpak run md.obsidian.Obsidian"
alias spacecat="tqs kitty kitty"
