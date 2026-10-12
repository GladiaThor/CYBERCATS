#!/usr/bin/env bash

set -euo pipefail
export CC_ROOT="$HOME/.cybercats"


SKIP_TOOLS=false
SKIP_ZSH_UTILS=false


for ARGUMENT in "$@"; do
    case "${ARGUMENT}" in
        --skiptools)
            SKIP_TOOLS=true
            ;;

        --skiputils)
            SKIP_ZSH_UTILS=true
            ;;
    esac
done


echo
echo "WELCOME TO CYBERCATS!"
echo "===================================="
echo

# =============================================================================
# Brew check
# =============================================================================

if ! command -v brew >/dev/null 2>&1; then
    echo "ERROR: Homebrew or Linuxbrew not found."
    echo 
    echo "For security reasons, CYBERCATS expects this to be installed manually."
    echo "Visit http://docs.brew.sh/Installation to install brew"
    echo "===================================="
    exit 1

fi


# =============================================================================
# Config
# =============================================================================

FONT_CASK="font-blex-mono-nerd-font"

FILES_TO_INSTALL=(
    ".zshrc"
)

DIRECTORIES_TO_INSTALL=(
    ".config"
    ".cybercats"
)


CORE_TOOLS=(
    "git:git"
    "neovim:nvim"
    "starship:starship"
    "ripgrep:rg"
    "fzf:fzf"
)


ZSH_UTILS=(
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
)

BUILTIN_POWERS=(
    "ccpower"
    "ccarchivist"
    "cckit"
    "ccupdate"
)

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CCARCHIVIST_SOURCE="${REPO_DIR}/.cybercats/powers/src/ccarchivist/ccarchivist.sh"

source "${CCARCHIVIST_SOURCE}"

BACKUP_ROOT="${HOME}/CYBERCATS_PRE_INSTALL_BACKUP"


# =============================================================================
# Preflight
# =============================================================================

echo "Validating CYBERCATS installation files."

for FILE in "${FILES_TO_INSTALL[@]}"; do
    SOURCE="${REPO_DIR}/${FILE}"

    if [[ ! -f "${SOURCE}" ]]; then
        echo "ERROR: Required file is missing:"
        echo "  ${SOURCE}"
        exit 1
    fi
done

for DIRECTORY in "${DIRECTORIES_TO_INSTALL[@]}"; do
    SOURCE="${REPO_DIR}/${DIRECTORY}"

    if [[ ! -d "${SOURCE}" ]]; then
        echo "ERROR: Required directory is missing:"
        echo "  ${SOURCE}"
        exit 1
    fi
done

echo "✓ Installation files validated."
echo


# =============================================================================
# Init and archiving 
# =============================================================================
echo "Fixing shell script permissions."

# If any tools fail to execute due to permission, uncomment these lines and rerun the installer.
# find "$REPO_DIR" -type f -iname "*.sh" -exec chmod +x {} \;
# find "$REPO_DIR" -type f -iname "*.zsh" -exec chmod +x {} \;


echo "Archiving existing configuration to ${BACKUP_ROOT}"
echo

ARCHIVE_SOURCES=()

for FILE in "${FILES_TO_INSTALL[@]}"; do
    ARCHIVE_SOURCES+=("${HOME}/${FILE}")
done

for DIRECTORY in "${DIRECTORIES_TO_INSTALL[@]}"; do
    ARCHIVE_SOURCES+=("${HOME}/${DIRECTORY}")
done

cybercats_ccarchivist \
    --archive \
    "${BACKUP_ROOT}" \
    "${ARCHIVE_SOURCES[@]}"

echo


# =============================================================================
# Core files
# =============================================================================

echo "Installing core files."

for FILE in "${FILES_TO_INSTALL[@]}"; do

    SOURCE="${REPO_DIR}/${FILE}"
    DESTINATION="${HOME}/${FILE}"

    if [[ ! -f "${SOURCE}" ]]; then
        echo "ERROR: Expected repository file does not exist:"
        echo "  ${SOURCE}"
        exit 1
    fi

    echo "  ${FILE}"

    cp "${SOURCE}" "${DESTINATION}"
done

echo

# =============================================================================
# Directories, dotfiles, and powers. 
# =============================================================================

echo "Installing configurations and powers."

for DIRECTORY in "${DIRECTORIES_TO_INSTALL[@]}"; do

    SOURCE="${REPO_DIR}/${DIRECTORY}"
    DESTINATION="${HOME}/${DIRECTORY}"

    if [[ ! -d "${SOURCE}" ]]; then
        echo "ERROR: Expected repository directory does not exist:"
        echo "  ${SOURCE}"
        exit 1
    fi

    echo "  ${DIRECTORY}/"

    cp -R "${SOURCE}" "${DESTINATION}"
done

echo

# =============================================================================
# Terminal Tools
# =============================================================================
if [[ "${SKIP_TOOLS}" == false ]]; then
echo "Installing terminal tools."

for TOOL_ENTRY in "${CORE_TOOLS[@]}"; do

    FORMULA="${TOOL_ENTRY%%:*}"
    COMMAND="${TOOL_ENTRY#*:}"

    # If your tools install correctly but you still get errors, uncoment these lines to see how the tool name maps to the tool command.
    # echo "Formula: ${FORMULA}"
    # echo "Command: ${COMMAND}"

done
BREW_PREFIX="$(brew --prefix)"

for TOOL_ENTRY in "${CORE_TOOLS[@]}"; do

    FORMULA="${TOOL_ENTRY%%:*}"
    COMMAND="${TOOL_ENTRY#*:}"

    if brew list --formula "${FORMULA}" >/dev/null 2>&1; then
        echo "✓ ${FORMULA} is already installed."
        continue
    fi

    echo "Installing ${FORMULA}..."
    # brew install "${FORMULA}"

    if ! brew list --formula "${FORMULA}" >/dev/null 2>&1; then
        echo "ERROR: ${FORMULA} failed to install."
        continue
    fi

    RESOLVED_PATH="$(command -v "${COMMAND}" || true)"

    echo "✓ ${FORMULA} installed."

    if [[ "${RESOLVED_PATH}" == "${BREW_PREFIX}"/* ]]; then
        echo "✓ ${COMMAND} -> ${RESOLVED_PATH}"

    elif [[ -n "${RESOLVED_PATH}" ]]; then
        echo "WARNING: You have a variant of ${FORMULA} installed that is not managed by Homebrew."
        echo "Although it will be ignored from now on, you should probably uninstall this version:"
        echo "  ${RESOLVED_PATH}"

    else
        echo "WARNING: ${FORMULA} was installed by Homebrew, but ${COMMAND} is not currently on PATH."
    fi

done

echo
echo "Core tools installed."
echo

else
    echo "Skipping core terminal tools."
    echo
fi

# =============================================================================
# ZSH Utils
# =============================================================================
if [[ "${SKIP_ZSH_UTILS}" == false ]]; then

echo "Installing zsh utils."

for TOOL in "${ZSH_UTILS[@]}"; do
    if brew list --formula "${TOOL}" >/dev/null 2>&1; then
        echo "✓ ${TOOL} is already installed."
        continue
    fi

    echo "Installing ${TOOL}..."
    # brew install "${TOOL}"

    if brew list --formula "${TOOL}" >/dev/null 2>&1; then
        echo "✓ ${TOOL} installed."
    else
        echo "ERROR: ${TOOL} failed to install."
    fi
done
echo
echo "ZSH utils installed."
echo

else
    echo "Skipping Zsh utilities."
    echo
fi

# =============================================================================
# Builtin Powers
# =============================================================================
source "${HOME}/.cybercats/powers/src/ccpower/ccpower.zsh"


echo "Installing builtin powers."

POWER_ROOT="${HOME}/.cybercats/powers"

mkdir -p "${POWER_ROOT}/builtins"

# Bootstrap the wrapper generator itself.
source "${POWER_ROOT}/src/ccpower/ccpower.zsh"

for POWER in "${BUILTIN_POWERS[@]}"; do

    POWER_MANIFEST="${POWER_ROOT}/src/${POWER}/power.toml"
    POWER_BUILTIN="${POWER_ROOT}/builtins/${POWER}.zsh"

    echo "Installing ${POWER}."

    if [[ ! -f "${POWER_MANIFEST}" ]]; then
        echo "ERROR: Manifest not found for ${POWER}:"
        echo "  ${POWER_MANIFEST}"
        exit 1
    fi

    echo "Generating wrapper for ${POWER}."
    
    cybercats_ccpower_set_origin \
        "${POWER_MANIFEST}" \
        "builtins"

    cybercats_ccpower_generate_wrapper \
        "${POWER_MANIFEST}" \
        "${POWER_BUILTIN}"

    if [[ ! -f "${POWER_BUILTIN}" ]]; then
        echo "ERROR: Failed to generate ${POWER} built-in wrapper."
        exit 1
    fi

    echo "✓ ${POWER} installed."
done



# =============================================================================
# Ghostty and Nerdfont 
# =============================================================================

bash "$REPO_DIR/install-scripts/install-ghostty.sh"

if ! brew list --cask "$FONT_CASK" &>/dev/null; then
    echo "Installing $FONT_CASK..."
    # brew install --cask "$FONT_CASK"
    echo "✓ $FONT_CASK installed."
else
    echo "Font already installed through Homebrew."
fi


# =============================================================================
# Done
# =============================================================================

echo "CYBERCATS Core installation complete!" 
echo "Restart your terminal to get going."
echo
