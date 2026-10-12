
#!/usr/bin/env bash
set -euo pipefail


# =============================================================================
# CYBERCATS Ghostty Installer v 1.0
#
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2017-2026 Thor K Salehi
# =============================================================================

install_ghostty() {
    command -v brew >/dev/null 2>&1 ||
        fail "Homebrew is required. Run the Cybercats Homebrew setup first."

    if [[ ! -d /Applications/Ghostty.app ]] &&
       ! brew list --cask ghostty &>/dev/null; then
        echo "Installing Ghostty..."
        brew install --cask ghostty
        echo "✓ Ghostty installed."
    else
        echo "Ghostty already installed."
    fi


}


main() {
    echo "Cybercats is tested and built for Ghostty (https://ghostty.org/).";
    local prompt="${1:-Would you like to install Ghostty terminal emulator?}"
    local answer
    
    while true; do
        read -r -p "$prompt [Y/n] " answer || return 1

        case "$answer" in
            [Yy]|[Yy][Ee][Ss]|"") 
                install_ghostty 
                break
                ;;
                
            [Nn]|[Nn][Oo])  
                echo "Skipping Ghostty. Don't forget to configure your terminal to use BlexMono Nerd Font" 
                break
                ;;

            *) "Please answer yes or no." ;;
        esac
    done
    

}

main "$@"
