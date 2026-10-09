#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# Cybercat Archive Utility v2019.3
# This is a little different than the rest of the powers since it needs to 
# run in any bash terminal as part of the installer. Yippie.
#
# Usage:
#
#   ./archive.sh <archive-root> <source> [source...]
#
# Example:
#
#   ./archive.sh \
#       "$HOME/CYBERCATS_PRE_INSTALL_BACKUP" \
#       "$HOME/.zshrc" \
#       "$HOME/.config"
#
# Creates:
#
#   ~/CYBERCATS_PRE_INSTALL_BACKUP/
#       2026-10-08_01-30-42/
#           .zshrc
#           .config/
#
# Sources that do not exist are skipped.
# =============================================================================

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <archive-root> <source> [source...]"
    exit 1
fi

ARCHIVE_ROOT="$1"
shift

TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
ARCHIVE_DIR="${ARCHIVE_ROOT}/${TIMESTAMP}"
echo "Verifying archive directory"

mkdir -p "${ARCHIVE_DIR}"

echo "Creating archive:"
echo "  ${ARCHIVE_DIR}"
echo

ARCHIVED_COUNT=0

for SOURCE in "$@"; do

    if [[ ! -e "${SOURCE}" && ! -L "${SOURCE}" ]]; then
        echo "Skipping missing source: ${SOURCE}"
        continue
    fi

    SOURCE_NAME="$(basename "${SOURCE}")"
    DESTINATION="${ARCHIVE_DIR}/${SOURCE_NAME}"

    if [[ -e "${DESTINATION}" || -L "${DESTINATION}" ]]; then
        echo "ERROR: Archive collision:"
        echo "  ${DESTINATION}"
        echo
        echo "Two archive sources appear to have the same name."
        exit 1
    fi

    echo "Archiving ${SOURCE}"
    mv "${SOURCE}" "${DESTINATION}"

    ARCHIVED_COUNT=$((ARCHIVED_COUNT + 1))
done

echo

if [[ ${ARCHIVED_COUNT} -eq 0 ]]; then
    echo "Nothing needed to be archived."

    # Don't leave an empty timestamp directory behind.
    rmdir "${ARCHIVE_DIR}"

    exit 0
fi

echo "Archived ${ARCHIVED_COUNT} item(s) to:"
echo "  ${ARCHIVE_DIR}"