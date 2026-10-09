#!/usr/bin/env bash

# =============================================================================
# CCArchivist
#
# CYBERCATS timestamped archive utility.
#
# This Power deliberately uses Bash-compatible syntax because it is required
# during the CYBERCATS bootstrap process before the user's shell environment
# has been configured.
#
# Framework commands such as:
#
#   --help
#   --description
#   --version
#   --source
#
# are implemented by the generated Power wrapper.
# =============================================================================


cybercats_ccarchivist() {
    local command="${1:-}"

    case "${command}" in

        --archive)
            shift
            cybercats_ccarchivist_archive "$@"
            ;;

        "")
            echo "Usage:"
            echo "  ccarchivist --archive <archive-root> <source> [source...]"
            return 1
            ;;

        *)
            echo "ERROR: Unknown CCArchivist command: ${command}"
            echo
            echo "Usage:"
            echo "  ccarchivist --archive <archive-root> <source> [source...]"
            return 1
            ;;
    esac
}


cybercats_ccarchivist_archive() {
    if [[ $# -lt 2 ]]; then
        echo "Usage:"
        echo "  ccarchivist --archive <archive-root> <source> [source...]"
        return 1
    fi

    local archive_root="${1}"
    shift

    local timestamp
    local archive_directory
    local archived_count=0

    timestamp="$(date +"%Y-%m-%d_%H-%M-%S")"
    archive_directory="${archive_root}/${timestamp}"

    echo "Verifying archive directory."

    if ! mkdir -p "${archive_directory}"; then
        echo "ERROR: Unable to create archive directory:"
        echo "  ${archive_directory}"
        return 1
    fi

    echo "Creating archive:"
    echo "  ${archive_directory}"
    echo

    local source
    local source_name
    local destination

    for source in "$@"; do

        if [[ ! -e "${source}" && ! -L "${source}" ]]; then
            echo "Skipping missing source: ${source}"
            continue
        fi

        source_name="$(basename "${source}")"
        destination="${archive_directory}/${source_name}"

        if [[ -e "${destination}" || -L "${destination}" ]]; then
            echo "ERROR: Archive collision:"
            echo "  ${destination}"
            echo
            echo "Two archive sources appear to have the same name."
            return 1
        fi

        echo "Archiving ${source}"

        if ! mv "${source}" "${destination}"; then
            echo "ERROR: Failed to archive:"
            echo "  ${source}"
            return 1
        fi

        archived_count=$((archived_count + 1))
    done

    echo

    if [[ ${archived_count} -eq 0 ]]; then
        echo "Nothing needed to be archived."

        # Don't leave an empty timestamp directory behind.
        rmdir "${archive_directory}" 2>/dev/null || true

        return 0
    fi

    echo "Archived ${archived_count} item(s) to:"
    echo "  ${archive_directory}"

    return 0
}