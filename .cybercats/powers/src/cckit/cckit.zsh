#!/usr/bin/env bash

# =============================================================================
# CCKit
#
# Homebrew package management with CYBERCATS kit tracking.
#
# Every package managed by CCKit belongs to the "local" kit.
#
# Packages may additionally belong to any number of named kits:
#
#   cckit install pyenv -k python
#   cckit install node -k react_web -k javascript
#
# Existing Homebrew packages can be adopted:
#
#   cckit kit neovim -k terminal
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

        kit)
            shift
            cybercats_cckit_kit "$@"
            ;;

        unkit)
            shift
            cybercats_cckit_unkit "$@"
            ;;

        kits)
            shift
            cybercats_cckit_kits "$@"
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


cybercats_cckit_kits_root() {
    echo "$(cybercats_cckit_root)/kits"
}


cybercats_cckit_kit_path() {
    local kit_name="${1}"

    echo "$(cybercats_cckit_kits_root)/${kit_name}.toml"
}


# =============================================================================
# Install
# =============================================================================

cybercats_cckit_install() {
    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  cckit install <formula> [-k <kit>]"
        echo "  cckit install --cask <cask> [-k <kit>]"
        return 1
    fi

    local is_cask=false

    local brew_arguments=()
    local packages=()
    local kits=()

    cybercats_cckit_parse_package_arguments \
        brew_arguments \
        packages \
        kits \
        is_cask \
        "$@" || return 1

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No package specified."
        return 1
    fi

    if ! brew install "${brew_arguments[@]}"; then
        echo "ERROR: Homebrew installation failed."
        return 1
    fi

    local package
    local kit

    for package in "${packages[@]}"; do

        # Everything managed by CCKit belongs to local.
        cybercats_cckit_add_to_kit \
            "local" \
            "${package}" \
            "${is_cask}" || return 1

        for kit in "${kits[@]}"; do
            cybercats_cckit_add_to_kit \
                "${kit}" \
                "${package}" \
                "${is_cask}" || return 1
        done

    done
}


# =============================================================================
# Kit
#
# Adopt something that is already installed through Homebrew and add it to
# one or more CYBERCATS kits.
# =============================================================================

cybercats_cckit_kit() {
    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  cckit kit <formula> -k <kit>"
        echo "  cckit kit --cask <cask> -k <kit>"
        return 1
    fi

    local is_cask=false

    local ignored_brew_arguments=()
    local packages=()
    local kits=()

    cybercats_cckit_parse_package_arguments \
        ignored_brew_arguments \
        packages \
        kits \
        is_cask \
        "$@" || return 1

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No package specified."
        return 1
    fi

    if [[ ${#kits[@]} -eq 0 ]]; then
        echo "ERROR: kit requires at least one -k or --kit."
        return 1
    fi

    local package
    local kit

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

        # Anything adopted into CCKit is also part of local.
        cybercats_cckit_add_to_kit \
            "local" \
            "${package}" \
            "${is_cask}" || return 1

        for kit in "${kits[@]}"; do
            cybercats_cckit_add_to_kit \
                "${kit}" \
                "${package}" \
                "${is_cask}" || return 1
        done

        echo "✓ Added ${package} to CCKit."

    done
}


# =============================================================================
# Unkit
#
# Remove package membership from one or more kits without uninstalling it.
# =============================================================================

cybercats_cckit_unkit() {
    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  cckit unkit <formula> -k <kit>"
        echo "  cckit unkit --cask <cask> -k <kit>"
        return 1
    fi

    local is_cask=false

    local ignored_brew_arguments=()
    local packages=()
    local kits=()

    cybercats_cckit_parse_package_arguments \
        ignored_brew_arguments \
        packages \
        kits \
        is_cask \
        "$@" || return 1

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No package specified."
        return 1
    fi

    if [[ ${#kits[@]} -eq 0 ]]; then
        echo "ERROR: unkit requires at least one -k or --kit."
        return 1
    fi

    local package
    local kit

    for package in "${packages[@]}"; do

        for kit in "${kits[@]}"; do

            if [[ "${kit}" == "local" ]]; then
                echo "ERROR: Packages cannot be removed from the local kit."
                echo "Use 'cckit uninstall ${package}' instead."
                continue
            fi

            cybercats_cckit_remove_from_kit \
                "${kit}" \
                "${package}" \
                "${is_cask}" || return 1

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
    local ignored_kits=()

    cybercats_cckit_parse_package_arguments \
        brew_arguments \
        packages \
        ignored_kits \
        is_cask \
        "$@" || return 1

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No package specified."
        return 1
    fi

    if ! brew uninstall "${brew_arguments[@]}"; then
        echo "ERROR: Homebrew uninstall failed."
        return 1
    fi

    local package

    for package in "${packages[@]}"; do
        cybercats_cckit_remove_from_all_kits \
            "${package}" \
            "${is_cask}" || return 1
    done
}


# =============================================================================
# Argument parsing
#
# CCKit-specific options:
#
#   -k <kit>
#   --kit <kit>
#
# Everything else is passed through to Homebrew.
# =============================================================================

cybercats_cckit_parse_package_arguments() {
    local brew_array_name="${1}"
    local packages_array_name="${2}"
    local kits_array_name="${3}"
    local is_cask_variable_name="${4}"

    shift 4

    local argument

    while [[ $# -gt 0 ]]; do
        argument="${1}"

        case "${argument}" in

            -k|--kit)

                if [[ $# -lt 2 ]]; then
                    echo "ERROR: ${argument} requires a kit name."
                    return 1
                fi

                cybercats_cckit_validate_kit_name "${2}" || return 1

                eval "${kits_array_name}+=(\"\${2}\")"

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
# Kits
# =============================================================================

cybercats_cckit_kits() {
    local kits_root
    kits_root="$(cybercats_cckit_kits_root)"

    mkdir -p "${kits_root}"

    echo
    echo "CCKit Kits"
    echo "=========="
    echo

    local kit_file
    local found=false

    for kit_file in "${kits_root}/"*.toml; do
        [[ -f "${kit_file}" ]] || continue

        basename "${kit_file}" .toml
        found=true
    done

    if [[ "${found}" == false ]]; then
        echo "No kits found."
    fi

    echo
}


cybercats_cckit_show() {
    local kit_name="${1:-}"

    if [[ -z "${kit_name}" ]]; then
        echo "Usage:"
        echo "  cckit show <kit>"
        return 1
    fi

    local kit_file
    kit_file="$(cybercats_cckit_kit_path "${kit_name}")"

    if [[ ! -f "${kit_file}" ]]; then
        echo "ERROR: Kit not found:"
        echo "  ${kit_name}"
        return 1
    fi

    echo
    echo "Kit: ${kit_name}"
    echo

    echo "Formulae:"
    cybercats_cckit_read_kit_entries \
        "${kit_file}" \
        "formulae"

    echo
    echo "Casks:"
    cybercats_cckit_read_kit_entries \
        "${kit_file}" \
        "casks"

    echo
}


# =============================================================================
# Kit modification
# =============================================================================

cybercats_cckit_add_to_kit() {
    local kit_name="${1}"
    local package="${2}"
    local is_cask="${3}"

    cybercats_cckit_validate_kit_name "${kit_name}" || return 1

    local section="formulae"

    if [[ "${is_cask}" == true ]]; then
        section="casks"
    fi

    cybercats_cckit_ensure_kit "${kit_name}"

    local kit_file
    kit_file="$(cybercats_cckit_kit_path "${kit_name}")"

    if cybercats_cckit_kit_contains \
        "${kit_file}" \
        "${section}" \
        "${package}"
    then
        return 0
    fi

    cybercats_cckit_rewrite_kit \
        "${kit_file}" \
        "${section}" \
        "add" \
        "${package}"
}


cybercats_cckit_remove_from_kit() {
    local kit_name="${1}"
    local package="${2}"
    local is_cask="${3}"

    local kit_file
    kit_file="$(cybercats_cckit_kit_path "${kit_name}")"

    [[ -f "${kit_file}" ]] || return 0

    local section="formulae"

    if [[ "${is_cask}" == true ]]; then
        section="casks"
    fi

    cybercats_cckit_rewrite_kit \
        "${kit_file}" \
        "${section}" \
        "remove" \
        "${package}"
}


cybercats_cckit_remove_from_all_kits() {
    local package="${1}"
    local is_cask="${2}"

    local kits_root
    kits_root="$(cybercats_cckit_kits_root)"

    local kit_file

    for kit_file in "${kits_root}/"*.toml; do
        [[ -f "${kit_file}" ]] || continue

        local kit_name
        kit_name="$(basename "${kit_file}" .toml)"

        cybercats_cckit_remove_from_kit \
            "${kit_name}" \
            "${package}" \
            "${is_cask}" || return 1
    done
}


# =============================================================================
# Kit creation
# =============================================================================

cybercats_cckit_ensure_kit() {
    local kit_name="${1}"

    local kit_file
    kit_file="$(cybercats_cckit_kit_path "${kit_name}")"

    [[ -f "${kit_file}" ]] && return 0

    mkdir -p "$(cybercats_cckit_kits_root)"

    cat > "${kit_file}" <<EOF
name = "${kit_name}"
id = "${kit_name}"

[formulae]
packages = []

[casks]
packages = []
EOF
}


cybercats_cckit_validate_kit_name() {
    local kit_name="${1}"

    if [[ ! "${kit_name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "ERROR: Invalid kit name:"
        echo "  ${kit_name}"
        echo
        echo "Kit names may contain letters, numbers, underscores and hyphens."
        return 1
    fi
}


# =============================================================================
# Kit reading
# =============================================================================

cybercats_cckit_kit_contains() {
    local kit_file="${1}"
    local section="${2}"
    local package="${3}"

    cybercats_cckit_read_kit_entries_raw \
        "${kit_file}" \
        "${section}" |
        grep -Fxq "${package}"
}


cybercats_cckit_read_kit_entries() {
    local kit_file="${1}"
    local section="${2}"

    local package
    local found=false

    while IFS= read -r package; do
        [[ -n "${package}" ]] || continue

        echo "  ${package}"
        found=true
    done < <(
        cybercats_cckit_read_kit_entries_raw \
            "${kit_file}" \
            "${section}"
    )

    if [[ "${found}" == false ]]; then
        echo "  None"
    fi
}


cybercats_cckit_read_kit_entries_raw() {
    local kit_file="${1}"
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
        ' "${kit_file}"
}


# =============================================================================
# Kit writer
#
# Rebuilds the kit from its current contents.
# =============================================================================

cybercats_cckit_rewrite_kit() {
    local kit_file="${1}"
    local section="${2}"
    local operation="${3}"
    local package="${4}"

    local kit_name
    kit_name="$(basename "${kit_file}" .toml)"

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
        cybercats_cckit_read_kit_entries_raw \
            "${kit_file}" \
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
        cybercats_cckit_read_kit_entries_raw \
            "${kit_file}" \
            "casks"
    )

    if [[ "${operation}" == "add" ]]; then

        if [[ "${section}" == "formulae" ]]; then
            formulae+=("${package}")
        else
            casks+=("${package}")
        fi

    fi

    cat > "${kit_file}" <<EOF
name = "${kit_name}"
id = "${kit_name}"

[formulae]
packages = [
EOF

    cybercats_cckit_write_toml_array \
        "${kit_file}" \
        "${formulae[@]}"

    cat >> "${kit_file}" <<'EOF'
]

[casks]
packages = [
EOF

    cybercats_cckit_write_toml_array \
        "${kit_file}" \
        "${casks[@]}"

    cat >> "${kit_file}" <<'EOF'
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