#!/usr/bin/env bash

# =============================================================================
# CCKit
#
# CYBERCATS-managed Homebrew interface.
#
# Normal Homebrew operations are passed through to brew.
# Install and uninstall operations additionally maintain a portable CYBERCATS
# manifest containing the packages explicitly managed through CCKit. This lets
# you separate what you want to have migratable and what you just have for a 
# specific machine.
# =============================================================================


cybercats_cckit() {
    local command="${1:-}"

    case "${command}" in

        install)
            shift
            cybercats_cckit_install "$@"
            ;;

        uninstall|remove)
            shift
            cybercats_cckit_uninstall "$@"
            ;;

        --manifest)
            cybercats_cckit_manifest
            ;;

        search|info|update|upgrade|list|doctor|cleanup|outdated)
            brew "${command}" "${@:2}"
            ;;

        "")
            echo "Usage:"
            echo "  cckit <command> [arguments]"
            return 1
            ;;

        *)
            echo "ERROR: Unknown CCKit command:"
            echo "  ${command}"
            return 1
            ;;
    esac
}


# =============================================================================
# Install
# =============================================================================

cybercats_cckit_install() {
    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  cckit install <formula>"
        echo "  cckit install --cask <cask>"
        return 1
    fi

    local is_cask=false
    local packages=()
    local argument

    for argument in "$@"; do
        case "${argument}" in
            --cask)
                is_cask=true
                ;;

            -*)
                # Preserve other Homebrew flags, but don't treat them as packages.
                ;;

            *)
                packages+=("${argument}")
                ;;
        esac
    done

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No package specified."
        return 1
    fi

    if ! brew install "$@"; then
        echo "ERROR: Homebrew installation failed."
        return 1
    fi

    for package in "${packages[@]}"; do
        if [[ "${is_cask}" == true ]]; then
            cybercats_cckit_track_cask "${package}"
        else
            cybercats_cckit_track_formula "${package}"
        fi
    done

    return 0
}


# =============================================================================
# Uninstall
# =============================================================================

cybercats_cckit_uninstall() {
    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  cckit uninstall <formula>"
        echo "  cckit uninstall --cask <cask>"
        return 1
    fi

    local is_cask=false
    local packages=()
    local argument

    for argument in "$@"; do
        case "${argument}" in
            --cask)
                is_cask=true
                ;;

            -*)
                ;;

            *)
                packages+=("${argument}")
                ;;
        esac
    done

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No package specified."
        return 1
    fi

    if ! brew uninstall "$@"; then
        echo "ERROR: Homebrew uninstall failed."
        return 1
    fi

    for package in "${packages[@]}"; do
        if [[ "${is_cask}" == true ]]; then
            cybercats_cckit_untrack_cask "${package}"
        else
            cybercats_cckit_untrack_formula "${package}"
        fi
    done

    return 0
}


# =============================================================================
# Manifest
# =============================================================================

cybercats_cckit_manifest_path() {
    echo "${HOME}/.cybercats/state/cckit.toml"
}


cybercats_cckit_ensure_manifest() {
    local manifest
    manifest="$(cybercats_cckit_manifest_path)"

    mkdir -p "$(dirname "${manifest}")"

    if [[ -f "${manifest}" ]]; then
        return 0
    fi

    cat > "${manifest}" <<'EOF'
version = 1

[formulae]
packages = []

[casks]
packages = []
EOF
}


cybercats_cckit_manifest() {
    cybercats_cckit_ensure_manifest

    local manifest
    manifest="$(cybercats_cckit_manifest_path)"

    echo
    echo "CCKit Managed Packages"
    echo "======================"
    echo

    echo "Formulae:"
    cybercats_cckit_read_packages "${manifest}" "formulae"

    echo
    echo "Casks:"
    cybercats_cckit_read_packages "${manifest}" "casks"

    echo
}


# =============================================================================
# Tracking
# =============================================================================

cybercats_cckit_track_formula() {
    cybercats_cckit_track_package "formulae" "${1}"
}


cybercats_cckit_track_cask() {
    cybercats_cckit_track_package "casks" "${1}"
}


cybercats_cckit_untrack_formula() {
    cybercats_cckit_untrack_package "formulae" "${1}"
}


cybercats_cckit_untrack_cask() {
    cybercats_cckit_untrack_package "casks" "${1}"
}


cybercats_cckit_track_package() {
    local section="${1}"
    local package="${2}"

    cybercats_cckit_ensure_manifest

    local manifest
    manifest="$(cybercats_cckit_manifest_path)"

    if cybercats_cckit_package_is_tracked "${manifest}" "${section}" "${package}"; then
        return 0
    fi

    cybercats_cckit_write_package_list \
        "${manifest}" \
        "${section}" \
        "add" \
        "${package}"
}


cybercats_cckit_untrack_package() {
    local section="${1}"
    local package="${2}"

    cybercats_cckit_ensure_manifest

    local manifest
    manifest="$(cybercats_cckit_manifest_path)"

    cybercats_cckit_write_package_list \
        "${manifest}" \
        "${section}" \
        "remove" \
        "${package}"
}


# =============================================================================
# Manifest helpers
# =============================================================================

cybercats_cckit_package_is_tracked() {
    local manifest="${1}"
    local section="${2}"
    local package="${3}"

    cybercats_cckit_read_packages_raw "${manifest}" "${section}" |
        grep -Fxq "${package}"
}


cybercats_cckit_read_packages() {
    local manifest="${1}"
    local section="${2}"

    local found=false
    local package

    while IFS= read -r package; do
        [[ -z "${package}" ]] && continue

        echo "  ${package}"
        found=true
    done < <(
        cybercats_cckit_read_packages_raw "${manifest}" "${section}"
    )

    if [[ "${found}" == false ]]; then
        echo "  None"
    fi
}


cybercats_cckit_read_packages_raw() {
    local manifest="${1}"
    local requested_section="${2}"

    awk \
        -v requested_section="${requested_section}" \
        '
        BEGIN {
            section = ""
            in_packages = 0
        }

        /^[[:space:]]*\[/ {
            line = $0
            gsub(/^[[:space:]]*\[/, "", line)
            gsub(/\][[:space:]]*$/, "", line)

            section = line
            in_packages = 0
            next
        }

        section == requested_section &&
        /^[[:space:]]*packages[[:space:]]*=/ {
            in_packages = 1

            line = $0
            sub(/^[^=]*=[[:space:]]*/, "", line)

            if (line ~ /\]/) {
                in_packages = 0
            }

            gsub(/[\[\]"]/, "", line)
            gsub(/,/, "\n", line)

            count = split(line, items, "\n")

            for (i = 1; i <= count; i++) {
                item = items[i]
                gsub(/^[[:space:]]+/, "", item)
                gsub(/[[:space:]]+$/, "", item)

                if (item != "") {
                    print item
                }
            }

            next
        }

        section == requested_section && in_packages {
            line = $0

            if (line ~ /\]/) {
                in_packages = 0
            }

            gsub(/[\[\]"]/, "", line)
            gsub(/,/, "\n", line)

            count = split(line, items, "\n")

            for (i = 1; i <= count; i++) {
                item = items[i]
                gsub(/^[[:space:]]+/, "", item)
                gsub(/[[:space:]]+$/, "", item)

                if (item != "") {
                    print item
                }
            }
        }
        ' "${manifest}"
}


cybercats_cckit_write_package_list() {
    local manifest="${1}"
    local section="${2}"
    local operation="${3}"
    local package="${4}"

    local temporary
    temporary="$(mktemp "${TMPDIR:-/tmp}/cckit.XXXXXX")" || return 1

    local packages=()
    local existing

    while IFS= read -r existing; do
        [[ -z "${existing}" ]] && continue

        if [[ "${operation}" == "remove" && "${existing}" == "${package}" ]]; then
            continue
        fi

        packages+=("${existing}")
    done < <(
        cybercats_cckit_read_packages_raw "${manifest}" "${section}"
    )

    if [[ "${operation}" == "add" ]]; then
        packages+=("${package}")
    fi

    cybercats_cckit_rewrite_manifest_section \
        "${manifest}" \
        "${temporary}" \
        "${section}" \
        "${packages[@]}"

    mv "${temporary}" "${manifest}"
}


cybercats_cckit_rewrite_manifest_section() {
    local manifest="${1}"
    local output="${2}"
    local requested_section="${3}"
    shift 3

    local packages=("$@")

    awk \
        -v requested_section="${requested_section}" \
        -v replacement_file="${output}.packages" \
        '
        BEGIN {
            section = ""
            skipping_packages = 0
        }

        /^[[:space:]]*\[/ {
            line = $0
            clean = line

            gsub(/^[[:space:]]*\[/, "", clean)
            gsub(/\][[:space:]]*$/, "", clean)

            section = clean
            skipping_packages = 0

            print line
            next
        }

        section == requested_section &&
        /^[[:space:]]*packages[[:space:]]*=/ {

            while ((getline replacement < replacement_file) > 0) {
                print replacement
            }

            close(replacement_file)

            if ($0 !~ /\]/) {
                skipping_packages = 1
            }

            next
        }

        skipping_packages {
            if ($0 ~ /\]/) {
                skipping_packages = 0
            }

            next
        }

        {
            print
        }
        ' "${manifest}" > "${output}"

    {
        echo "packages = ["

        local index
        local count="${#packages[@]}"

        for ((index = 0; index < count; index++)); do
            if [[ ${index} -lt $((count - 1)) ]]; then
                echo "    \"${packages[$index]}\","
            else
                echo "    \"${packages[$index]}\""
            fi
        done

        echo "]"
    } > "${output}.packages"

    # Run again now that the replacement content exists.
    awk \
        -v requested_section="${requested_section}" \
        -v replacement_file="${output}.packages" \
        '
        BEGIN {
            section = ""
            skipping_packages = 0
        }

        /^[[:space:]]*\[/ {
            line = $0
            clean = line

            gsub(/^[[:space:]]*\[/, "", clean)
            gsub(/\][[:space:]]*$/, "", clean)

            section = clean
            skipping_packages = 0

            print line
            next
        }

        section == requested_section &&
        /^[[:space:]]*packages[[:space:]]*=/ {

            while ((getline replacement < replacement_file) > 0) {
                print replacement
            }

            close(replacement_file)

            if ($0 !~ /\]/) {
                skipping_packages = 1
            }

            next
        }

        skipping_packages {
            if ($0 ~ /\]/) {
                skipping_packages = 0
            }

            next
        }

        {
            print
        }
        ' "${manifest}" > "${output}"

    rm -f "${output}.packages"
}