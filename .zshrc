export CC_ROOT="$HOME/.cybercats"
source "$CC_ROOT/main.zsh"

# Your non-brew tools are bad and they should feel bad (and be ignored)
# Although I still recommend uninstalling the variants outside of brew.
BREW_PREFIX="$(brew --prefix)"
export PATH="${BREW_PREFIX}/bin:${BREW_PREFIX}/sbin:${PATH}"