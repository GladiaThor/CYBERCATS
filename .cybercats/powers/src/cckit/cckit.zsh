#!/usr/bin/env bash

# =============================================================================
# CCKit
#
# Homebrew package management with CYBERCATS pack tracking.
#
# Every package managed by CCKit belongs to the "local" pack.
#
# Packages may additionally belong to any number of named packs:
#
#   cckit install pyenv -p python
#   cckit install node -p react_web -p javascript
#
# Existing Homebrew packages can be adopted:
#
#   cckit pack neovim -p terminal
#
# =============================================================================


# =============================================================================
# Entrypoint
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

        pack)
            shift
            cybercats_cckit_pack "$@"
            ;;

        unpack)
            shift
            cybercats_cckit_unpack "$@"
            ;;

        packs)
            shift
            cybercats_cckit_packs "$@"
            ;;

        show)
            shift
            cybercats_cckit_show "$@"
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
# Paths
# =============================================================================

cybercats_cckit_root() {
    echo "${HOME}/.cybercats/cckit"
}


cybercats_cckit_packs_root() {
    echo "$(cybercats_cckit_root)/packs"
}


cybercats_cckit_pack_path() {
    local pack_name="${1}"

    echo "$(cybercats_cckit_packs_root)/${pack_name}.toml"
}


# =============================================================================
# Install
# =============================================================================

cybercats_cckit_install() {
    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  cckit install <formula> [-p <pack>]"
        echo "  cckit install --cask <cask> [-p <pack>]"
        return 1
    fi

    local is_cask=false

    local brew_arguments=()
    local packages=()
    local packs=()

    cybercats_cckit_parse_package_arguments \
        brew_arguments \
        packages \
        packs \
        is_cask \
        "$@"

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No package specified."
        return 1
    fi

    if ! brew install "${brew_arguments[@]}"; then
        echo "ERROR: Homebrew installation failed."
        return 1
    fi

    local package
    local pack

    for package in "${packages[@]}"; do

        # Everything managed by CCKit belongs to local.
        cybercats_cckit_add_to_pack \
            "local" \
            "${package}" \
            "${is_cask}"

        for pack in "${packs[@]}"; do
            cybercats_cckit_add_to_pack \
                "${pack}" \
                "${package}" \
                "${is_cask}"
        done

    done
}


# =============================================================================
# Pack
#
# Adopt something that is already installed through Homebrew.
# =============================================================================

cybercats_cckit_pack() {
    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  cckit pack <formula> -p <pack>"
        echo "  cckit pack --cask <cask> -p <pack>"
        return 1
    fi

    local is_cask=false

    local ignored_brew_arguments=()
    local packages=()
    local packs=()

    cybercats_cckit_parse_package_arguments \
        ignored_brew_arguments \
        packages \
        packs \
        is_cask \
        "$@"

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No package specified."
        return 1
    fi

    if [[ ${#packs[@]} -eq 0 ]]; then
        echo "ERROR: pack requires at least one -p or --packname."
        return 1
    fi

    local package
    local pack

    for package in "${packages[@]}"; do

        if [[ "${is_cask}" == true ]]; then

            if ! brew list --cask "${package}" >/dev/null 2>&1; then
                echo "ERROR: Cask is not installed:"
                echo "  ${package}"
                continue
            fi

        else

            if ! brew list --formula "${package}" >/dev/null 2>&1; then
                echo "ERROR: Formula is not installed:"
                echo "  ${package}"
                continue
            fi

        fi

        # Adopting something into CCKit also makes it part of local.
        cybercats_cckit_add_to_pack \
            "local" \
            "${package}" \
            "${is_cask}"

        for pack in "${packs[@]}"; do
            cybercats_cckit_add_to_pack \
                "${pack}" \
                "${package}" \
                "${is_cask}"
        done

        echo "✓ Packed ${package}."

    done
}


# =============================================================================
# Unpack
# =============================================================================

cybercats_cckit_unpack() {
    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  cckit unpack <formula> -p <pack>"
        echo "  cckit unpack --cask <cask> -p <pack>"
        return 1
    fi

    local is_cask=false

    local ignored_brew_arguments=()
    local packages=()
    local packs=()

    cybercats_cckit_parse_package_arguments \
        ignored_brew_arguments \
        packages \
        packs \
        is_cask \
        "$@"

    if [[ ${#packs[@]} -eq 0 ]]; then
        echo "ERROR: unpack requires at least one -p or --packname."
        return 1
    fi

    local package
    local pack

    for package in "${packages[@]}"; do

        for pack in "${packs[@]}"; do

            if [[ "${pack}" == "local" ]]; then
                echo "ERROR: Packages cannot be unpacked from local."
                echo "Use 'cckit uninstall ${package}' instead."
                continue
            fi

            cybercats_cckit_remove_from_pack \
                "${pack}" \
                "${package}" \
                "${is_cask}"

        done

    done
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

    local brew_arguments=()
    local packages=()
    local ignored_packs=()

    cybercats_cckit_parse_package_arguments \
        brew_arguments \
        packages \
        ignored_packs \
        is_cask \
        "$@"

    if ! brew uninstall "${brew_arguments[@]}"; then
        echo "ERROR: Homebrew uninstall failed."
        return 1
    fi

    local package

    for package in "${packages[@]}"; do
        cybercats_cckit_remove_from_all_packs \
            "${package}" \
            "${is_cask}"
    done
}


# =============================================================================
# Argument parsing
#
# Bash does not have references, so these array names are passed by name and
# populated using eval.
#
# Supported CCKit arguments:
#
#   -p <pack>
#   --packname <pack>
#
# Everything else is passed through to Brew.
# =============================================================================

cybercats_cckit_parse_package_arguments() {
    local brew_array_name="${1}"
    local packages_array_name="${2}"
    local packs_array_name="${3}"
    local is_cask_variable_name="${4}"

    shift 4

    local argument

    while [[ $# -gt 0 ]]; do
        argument="${1}"

        case "${argument}" in

            -p|--packname)

                if [[ $# -lt 2 ]]; then
                    echo "ERROR: ${argument} requires a pack name."
                    return 1
                fi

                cybercats_cckit_validate_pack_name "${2}" || return 1

                eval "${packs_array_name}+=(\"\${2}\")"

                shift 2
                ;;

            --cask)

                eval "${is_cask_variable_name}=true"
                eval "${brew_array_name}+=(\"--cask\")"

                shift
                ;;

            -*)

                eval "${brew_array_name}+=(\"\${argument}\")"

                shift
                ;;

            *)

                eval "${brew_array_name}+=(\"\${argument}\")"
                eval "${packages_array_name}+=(\"\${argument}\")"

                shift
                ;;

        esac
    done
}


# =============================================================================
# Packs
# =============================================================================

cybercats_cckit_packs() {
    local packs_root
    packs_root="$(cybercats_cckit_packs_root)"

    mkdir -p "${packs_root}"

    echo
    echo "CCKit Packs"
    echo "==========="
    echo

    local pack_file
    local found=false

    for pack_file in "${packs_root}/"*.toml; do
        [[ -f "${pack_file}" ]] || continue

        basename "${pack_file}" .toml
        found=true
    done

    if [[ "${found}" == false ]]; then
        echo "No packs found."
    fi

    echo
}


cybercats_cckit_show() {
    local pack_name="${1:-}"

    if [[ -z "${pack_name}" ]]; then
        echo "Usage:"
        echo "  cckit show <pack>"
        return 1
    fi

    local pack_file
    pack_file="$(cybercats_cckit_pack_path "${pack_name}")"

    if [[ ! -f "${pack_file}" ]]; then
        echo "ERROR: Pack not found:"
        echo "  ${pack_name}"
        return 1
    fi

    echo
    echo "Pack: ${pack_name}"
    echo

    echo "Formulae:"
    cybercats_cckit_read_pack_entries \
        "${pack_file}" \
        "formulae"

    echo
    echo "Casks:"
    cybercats_cckit_read_pack_entries \
        "${pack_file}" \
        "casks"

    echo
}


# =============================================================================
# Pack modification
# =============================================================================

cybercats_cckit_add_to_pack() {
    local pack_name="${1}"
    local package="${2}"
    local is_cask="${3}"

    cybercats_cckit_validate_pack_name "${pack_name}" || return 1

    local section="formulae"

    if [[ "${is_cask}" == true ]]; then
        section="casks"
    fi

    cybercats_cckit_ensure_pack "${pack_name}"

    local pack_file
    pack_file="$(cybercats_cckit_pack_path "${pack_name}")"

    if cybercats_cckit_pack_contains \
        "${pack_file}" \
        "${section}" \
        "${package}"
    then
        return 0
    fi

    cybercats_cckit_rewrite_pack \
        "${pack_file}" \
        "${section}" \
        "add" \
        "${package}"
}


cybercats_cckit_remove_from_pack() {
    local pack_name="${1}"
    local package="${2}"
    local is_cask="${3}"

    local pack_file
    pack_file="$(cybercats_cckit_pack_path "${pack_name}")"

    [[ -f "${pack_file}" ]] || return 0

    local section="formulae"

    if [[ "${is_cask}" == true ]]; then
        section="casks"
    fi

    cybercats_cckit_rewrite_pack \
        "${pack_file}" \
        "${section}" \
        "remove" \
        "${package}"
}


cybercats_cckit_remove_from_all_packs() {
    local package="${1}"
    local is_cask="${2}"

    local packs_root
    packs_root="$(cybercats_cckit_packs_root)"

    local pack_file

    for pack_file in "${packs_root}/"*.toml; do
        [[ -f "${pack_file}" ]] || continue

        local pack_name
        pack_name="$(basename "${pack_file}" .toml)"

        cybercats_cckit_remove_from_pack \
            "${pack_name}" \
            "${package}" \
            "${is_cask}"
    done
}


# =============================================================================
# Pack creation
# =============================================================================

cybercats_cckit_ensure_pack() {
    local pack_name="${1}"

    local pack_file
    pack_file="$(cybercats_cckit_pack_path "${pack_name}")"

    [[ -f "${pack_file}" ]] && return 0

    mkdir -p "$(cybercats_cckit_packs_root)"

    cat > "${pack_file}" <<EOF
name = "${pack_name}"
id = "${pack_name}"

[formulae]
packages = []

[casks]
packages = []
EOF
}


cybercats_cckit_validate_pack_name() {
    local pack_name="${1}"

    if [[ ! "${pack_name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "ERROR: Invalid pack name:"
        echo "  ${pack_name}"
        echo
        echo "Pack names may contain letters, numbers, underscores and hyphens."
        return 1
    fi
}


# =============================================================================
# Pack reading
# =============================================================================

cybercats_cckit_pack_contains() {
    local pack_file="${1}"
    local section="${2}"
    local package="${3}"

    cybercats_cckit_read_pack_entries_raw \
        "${pack_file}" \
        "${section}" |
        grep -Fxq "${package}"
}


cybercats_cckit_read_pack_entries() {
    local pack_file="${1}"
    local section="${2}"

    local package
    local found=false

    while IFS= read -r package; do
        [[ -n "${package}" ]] || continue

        echo "  ${package}"
        found=true
    done < <(
        cybercats_cckit_read_pack_entries_raw \
            "${pack_file}" \
            "${section}"
    )

    if [[ "${found}" == false ]]; then
        echo "  None"
    fi
}


cybercats_cckit_read_pack_entries_raw() {
    local pack_file="${1}"
    local requested_section="${2}"

    awk \
        -v requested_section="${requested_section}" \
        '
        BEGIN {
            section = ""
            reading_packages = 0
        }

        /^[[:space:]]*\[/ {
            line = $0

            gsub(/^[[:space:]]*\[/, "", line)
            gsub(/\][[:space:]]*$/, "", line)

            section = line
            reading_packages = 0

            next
        }

        section == requested_section &&
        /^[[:space:]]*packages[[:space:]]*=/ {

            reading_packages = 1

            line = $0
            sub(/^[^=]*=[[:space:]]*/, "", line)

            if (line ~ /\]/) {
                reading_packages = 0
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

        section == requested_section && reading_packages {

            line = $0

            if (line ~ /\]/) {
                reading_packages = 0
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
        ' "${pack_file}"
}


# =============================================================================
# Pack writer
#
# Rebuilds the pack from its current content.
# =============================================================================

cybercats_cckit_rewrite_pack() {
    local pack_file="${1}"
    local section="${2}"
    local operation="${3}"
    local package="${4}"

    local pack_name
    pack_name="$(basename "${pack_file}" .toml)"

    local formulae=()
    local casks=()

    local existing

    while IFS= read -r existing; do
        [[ -n "${existing}" ]] || continue

        if [[ "${section}" == "formulae" &&
              "${operation}" == "remove" &&
              "${existing}" == "${package}" ]]
        then
            continue
        fi

        formulae+=("${existing}")
    done < <(
        cybercats_cckit_read_pack_entries_raw \
            "${pack_file}" \
            "formulae"
    )

    while IFS= read -r existing; do
        [[ -n "${existing}" ]] || continue

        if [[ "${section}" == "casks" &&
              "${operation}" == "remove" &&
              "${existing}" == "${package}" ]]
        then
            continue
        fi

        casks+=("${existing}")
    done < <(
        cybercats_cckit_read_pack_entries_raw \
            "${pack_file}" \
            "casks"
    )

    if [[ "${operation}" == "add" ]]; then

        if [[ "${section}" == "formulae" ]]; then
            formulae+=("${package}")
        else
            casks+=("${package}")
        fi

    fi

    cat > "${pack_file}" <<EOF
name = "${pack_name}"
id = "${pack_name}"

[formulae]
packages = [
EOF

    cybercats_cckit_write_toml_array \
        "${pack_file}" \
        "${formulae[@]}"

    cat >> "${pack_file}" <<'EOF'
]

[casks]
packages = [
EOF

    cybercats_cckit_write_toml_array \
        "${pack_file}" \
        "${casks[@]}"

    cat >> "${pack_file}" <<'EOF'
]
EOF
}


cybercats_cckit_write_toml_array() {
    local output="${1}"
    shift

    local values=("$@")
    local index
    local count="${#values[@]}"

    for ((index = 0; index < count; index++)); do

        if [[ ${index} -lt $((count - 1)) ]]; then
            echo "    \"${values[$index]}\"," >> "${output}"
        else
            echo "    \"${values[$index]}\"" >> "${output}"
        fi

    done
}