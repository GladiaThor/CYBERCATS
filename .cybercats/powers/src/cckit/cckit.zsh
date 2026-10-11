#!/usr/bin/env bash

# =============================================================================
# CCKit v1.3
#
# Homebrew and CYBERCATS Power management with kit tracking.
#
# Every item managed by CCKit belongs to the "local" kit.
#
# Items may additionally belong to any number of named kits:
#
#   cckit install pyenv -k python
#   cckit install --cask wezterm -k terminal
#   cckit install --power https://github.com/example/power.git -k terminal
#
# Existing items can be adopted:
#
#   cckit kit neovim -k terminal
#   cckit kit --power power_search -k terminal
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


cybercats_cckit_power_manifest() {
    local power_id="${1}"

    echo "${HOME}/.cybercats/powers/src/${power_id}/power.toml"
}


# =============================================================================
# Install
# =============================================================================

cybercats_cckit_install() {
    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  cckit install <formula> [-k <kit>]"
        echo "  cckit install --cask <cask> [-k <kit>]"
        echo "  cckit install --power <git repository> [-k <kit>]"
        return 1
    fi

    local is_cask=false
    local is_power=false

    local brew_arguments=()
    local packages=()
    local kits=()

    cybercats_cckit_parse_package_arguments \
        brew_arguments \
        packages \
        kits \
        is_cask \
        is_power \
        "$@" || return 1

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: Nothing specified to install."
        return 1
    fi

    if [[ "${is_cask}" == true && "${is_power}" == true ]]; then
        echo "ERROR: --cask and --power cannot be used together."
        return 1
    fi

    # -------------------------------------------------------------------------
    # Powers
    # -------------------------------------------------------------------------

    if [[ "${is_power}" == true ]]; then
        cybercats_cckit_install_powers \
            packages \
            kits

        return $?
    fi

    # -------------------------------------------------------------------------
    # Homebrew
    # -------------------------------------------------------------------------

    if ! brew install "${brew_arguments[@]}"; then
        echo "ERROR: Homebrew installation failed."
        return 1
    fi

    local package
    local kit

    for package in "${packages[@]}"; do

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
# Install Powers
# =============================================================================

cybercats_cckit_install_powers() {
    local packages_array_name="${1}"
    local kits_array_name="${2}"

    eval 'local power_origins=("${'"${packages_array_name}"'[@]}")'
    eval 'local kits=("${'"${kits_array_name}"'[@]}")'

    local requested_origin
    local power_id
    local power_origin
    local kit

    for requested_origin in "${power_origins[@]}"; do

        echo "Installing Power:"
        echo "  ${requested_origin}"

        if ! ccpower --install "${requested_origin}"; then
            echo "ERROR: Failed to install Power:"
            echo "  ${requested_origin}"
            continue
        fi

        power_id="$(
            cybercats_cckit_power_id_from_origin \
                "${requested_origin}"
        )"

        if [[ -z "${power_id}" ]]; then
            echo "ERROR: Power installed, but CCKit could not determine its ID."
            continue
        fi

        power_origin="$(
            cybercats_cckit_power_origin \
                "${power_id}"
        )"

        if [[ -z "${power_origin}" ]]; then
            echo "ERROR: Power does not contain origin metadata:"
            echo "  ${power_id}"
            continue
        fi

        cybercats_cckit_add_power_to_kit \
            "local" \
            "${power_id}" \
            "${power_origin}" || return 1

        for kit in "${kits[@]}"; do
            cybercats_cckit_add_power_to_kit \
                "${kit}" \
                "${power_id}" \
                "${power_origin}" || return 1
        done

        echo "✓ ${power_id} installed and tracked."

    done
}


# =============================================================================
# Kit
#
# Adopt an already installed formula, cask or Power.
# =============================================================================

cybercats_cckit_kit() {
    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  cckit kit <formula> -k <kit>"
        echo "  cckit kit --cask <cask> -k <kit>"
        echo "  cckit kit --power <power> -k <kit>"
        return 1
    fi

    local is_cask=false
    local is_power=false

    local ignored_brew_arguments=()
    local packages=()
    local kits=()

    cybercats_cckit_parse_package_arguments \
        ignored_brew_arguments \
        packages \
        kits \
        is_cask \
        is_power \
        "$@" || return 1

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No package or Power specified."
        return 1
    fi

    if [[ ${#kits[@]} -eq 0 ]]; then
        echo "ERROR: kit requires at least one -k or --kit."
        return 1
    fi

    if [[ "${is_cask}" == true && "${is_power}" == true ]]; then
        echo "ERROR: --cask and --power cannot be used together."
        return 1
    fi

    local package
    local kit

    for package in "${packages[@]}"; do

        # ---------------------------------------------------------------------
        # Power
        # ---------------------------------------------------------------------

        if [[ "${is_power}" == true ]]; then

            local power_manifest
            local power_origin

            power_manifest="$(
                cybercats_cckit_power_manifest \
                    "${package}"
            )"

            if [[ ! -f "${power_manifest}" ]]; then
                echo "ERROR: Power is not installed:"
                echo "  ${package}"
                continue
            fi

            power_origin="$(
                cybercats_cckit_power_origin \
                    "${package}"
            )"

            if [[ -z "${power_origin}" ]]; then
                echo "ERROR: Power does not contain origin metadata:"
                echo "  ${package}"
                continue
            fi

            cybercats_cckit_add_power_to_kit \
                "local" \
                "${package}" \
                "${power_origin}" || return 1

            for kit in "${kits[@]}"; do
                cybercats_cckit_add_power_to_kit \
                    "${kit}" \
                    "${package}" \
                    "${power_origin}" || return 1
            done

            echo "✓ Added Power ${package} to CCKit."

            continue
        fi

        # ---------------------------------------------------------------------
        # Homebrew
        # ---------------------------------------------------------------------

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
# Remove membership from one or more kits without uninstalling the item.
# =============================================================================

cybercats_cckit_unkit() {
    if [[ $# -eq 0 ]]; then
        echo "Usage:"
        echo "  cckit unkit <formula> -k <kit>"
        echo "  cckit unkit --cask <cask> -k <kit>"
        echo "  cckit unkit --power <power> -k <kit>"
        return 1
    fi

    local is_cask=false
    local is_power=false

    local ignored_brew_arguments=()
    local packages=()
    local kits=()

    cybercats_cckit_parse_package_arguments \
        ignored_brew_arguments \
        packages \
        kits \
        is_cask \
        is_power \
        "$@" || return 1

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No package or Power specified."
        return 1
    fi

    if [[ ${#kits[@]} -eq 0 ]]; then
        echo "ERROR: unkit requires at least one -k or --kit."
        return 1
    fi

    if [[ "${is_cask}" == true && "${is_power}" == true ]]; then
        echo "ERROR: --cask and --power cannot be used together."
        return 1
    fi

    local package
    local kit

    for package in "${packages[@]}"; do

        for kit in "${kits[@]}"; do

            if [[ "${kit}" == "local" ]]; then
                echo "ERROR: Items cannot be removed from the local kit."
                echo "Use 'cckit uninstall ${package}' instead."
                continue
            fi

            if [[ "${is_power}" == true ]]; then

                cybercats_cckit_remove_power_from_kit \
                    "${kit}" \
                    "${package}" || return 1

            else

                cybercats_cckit_remove_from_kit \
                    "${kit}" \
                    "${package}" \
                    "${is_cask}" || return 1

            fi

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
        echo "  cckit uninstall --power <power>"
        return 1
    fi

    local is_cask=false
    local is_power=false

    local brew_arguments=()
    local packages=()
    local ignored_kits=()

    cybercats_cckit_parse_package_arguments \
        brew_arguments \
        packages \
        ignored_kits \
        is_cask \
        is_power \
        "$@" || return 1

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No package or Power specified."
        return 1
    fi

    if [[ "${is_cask}" == true && "${is_power}" == true ]]; then
        echo "ERROR: --cask and --power cannot be used together."
        return 1
    fi

    local package

    # -------------------------------------------------------------------------
    # Powers
    # -------------------------------------------------------------------------

    if [[ "${is_power}" == true ]]; then

        for package in "${packages[@]}"; do

            if ! ccpower --remove "${package}"; then
                echo "ERROR: Failed to remove Power:"
                echo "  ${package}"
                continue
            fi

            cybercats_cckit_remove_power_from_all_kits \
                "${package}" || return 1

            echo "✓ ${package} removed from CCKit."

        done

        return 0
    fi

    # -------------------------------------------------------------------------
    # Homebrew
    # -------------------------------------------------------------------------

    if ! brew uninstall "${brew_arguments[@]}"; then
        echo "ERROR: Homebrew uninstall failed."
        return 1
    fi

    for package in "${packages[@]}"; do
        cybercats_cckit_remove_from_all_kits \
            "${package}" \
            "${is_cask}" || return 1
    done
}


# =============================================================================
# Argument parsing
#
# CCKit options:
#
#   -k <kit>
#   --kit <kit>
#
#   -p
#   --power
#
# Homebrew options such as --cask are otherwise passed through normally.
# =============================================================================

cybercats_cckit_parse_package_arguments() {
    local brew_array_name="${1}"
    local packages_array_name="${2}"
    local kits_array_name="${3}"
    local is_cask_variable_name="${4}"
    local is_power_variable_name="${5}"

    shift 5

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

            -p|--power)

                eval "${is_power_variable_name}=true"

                shift
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
    echo "Powers:"
    cybercats_cckit_read_powers \
        "${kit_file}"

    echo
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
# Formula / Cask kit modification
# =============================================================================

cybercats_cckit_add_to_kit() {
    local kit_name="${1}"
    local package="${2}"
    local is_cask="${3}"

    cybercats_cckit_validate_kit_name "${kit_name}" || return 1
    cybercats_cckit_ensure_kit "${kit_name}"

    local section="formulae"

    if [[ "${is_cask}" == true ]]; then
        section="casks"
    fi

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
# Power kit modification
# =============================================================================

cybercats_cckit_add_power_to_kit() {
    local kit_name="${1}"
    local power_id="${2}"
    local power_origin="${3}"

    cybercats_cckit_validate_kit_name "${kit_name}" || return 1
    cybercats_cckit_ensure_kit "${kit_name}"

    local kit_file
    kit_file="$(cybercats_cckit_kit_path "${kit_name}")"

    cybercats_cckit_rewrite_power_in_kit \
        "${kit_file}" \
        "add" \
        "${power_id}" \
        "${power_origin}"
}


cybercats_cckit_remove_power_from_kit() {
    local kit_name="${1}"
    local power_id="${2}"

    local kit_file
    kit_file="$(cybercats_cckit_kit_path "${kit_name}")"

    [[ -f "${kit_file}" ]] || return 0

    cybercats_cckit_rewrite_power_in_kit \
        "${kit_file}" \
        "remove" \
        "${power_id}" \
        ""
}


cybercats_cckit_remove_power_from_all_kits() {
    local power_id="${1}"

    local kits_root
    kits_root="$(cybercats_cckit_kits_root)"

    local kit_file

    for kit_file in "${kits_root}/"*.toml; do
        [[ -f "${kit_file}" ]] || continue

        local kit_name
        kit_name="$(basename "${kit_file}" .toml)"

        cybercats_cckit_remove_power_from_kit \
            "${kit_name}" \
            "${power_id}" || return 1
    done
}


# =============================================================================
# Formula / Cask reading
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

        /^[[:space:]]*\[\[/ {
            reading_packages = 0
            section = ""
            next
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
# Power metadata
# =============================================================================

cybercats_cckit_power_manifest_value() {
    local manifest="${1}"
    local requested_key="${2}"

    awk \
        -v requested_key="${requested_key}" \
        '
        BEGIN {
            in_top_level = 1
        }

        /^[[:space:]]*\[/ {
            in_top_level = 0
        }

        in_top_level {
            equals = index($0, "=")

            if (!equals) {
                next
            }

            key = substr($0, 1, equals - 1)
            value = substr($0, equals + 1)

            gsub(/^[[:space:]]+/, "", key)
            gsub(/[[:space:]]+$/, "", key)

            if (key != requested_key) {
                next
            }

            gsub(/^[[:space:]]+/, "", value)
            gsub(/[[:space:]]+$/, "", value)

            if (substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") {
                value = substr(value, 2, length(value) - 2)
            }

            print value
            exit
        }
        ' "${manifest}"
}


cybercats_cckit_power_origin() {
    local power_id="${1}"

    local manifest
    manifest="$(cybercats_cckit_power_manifest "${power_id}")"

    if [[ ! -f "${manifest}" ]]; then
        return 1
    fi

    cybercats_cckit_power_manifest_value \
        "${manifest}" \
        "origin"
}


cybercats_cckit_power_id_from_origin() {
    local requested_origin="${1}"

    local manifest
    local power_origin
    local power_id

    for manifest in "${HOME}/.cybercats/powers/src/"*/power.toml; do
        [[ -f "${manifest}" ]] || continue

        power_origin="$(
            cybercats_cckit_power_manifest_value \
                "${manifest}" \
                "origin"
        )"

        if [[ "${power_origin}" != "${requested_origin}" ]]; then
            continue
        fi

        power_id="$(
            cybercats_cckit_power_manifest_value \
                "${manifest}" \
                "id"
        )"

        if [[ -n "${power_id}" ]]; then
            echo "${power_id}"
            return 0
        fi
    done

    return 1
}


# =============================================================================
# Power reading
# =============================================================================

cybercats_cckit_kit_contains_power() {
    local kit_file="${1}"
    local requested_power_id="${2}"

    local power_id
    local power_origin

    while IFS=$'\t' read -r power_id power_origin; do

        if [[ "${power_id}" == "${requested_power_id}" ]]; then
            return 0
        fi

    done < <(
        cybercats_cckit_read_powers_raw \
            "${kit_file}"
    )

    return 1
}


cybercats_cckit_read_powers() {
    local kit_file="${1}"

    local found=false
    local power_id
    local power_origin

    while IFS=$'\t' read -r power_id power_origin; do
        [[ -n "${power_id}" ]] || continue

        printf "  %-24s %s\n" \
            "${power_id}" \
            "${power_origin}"

        found=true
    done < <(
        cybercats_cckit_read_powers_raw \
            "${kit_file}"
    )

    if [[ "${found}" == false ]]; then
        echo "  None"
    fi
}


cybercats_cckit_read_powers_raw() {
    local kit_file="${1}"

    awk '
    function clean(value) {
        sub(/^[^=]*=[[:space:]]*/, "", value)

        gsub(/^[[:space:]]+/, "", value)
        gsub(/[[:space:]]+$/, "", value)

        if (substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") {
            value = substr(value, 2, length(value) - 2)
        }

        return value
    }

    function emit_power() {
        if (power_id != "") {
            printf "%s\t%s\n", power_id, power_origin
        }
    }

    /^[[:space:]]*\[\[powers\]\]/ {
        emit_power()

        power_id = ""
        power_origin = ""
        in_power = 1

        next
    }

    in_power && /^[[:space:]]*\[/ {
        emit_power()

        power_id = ""
        power_origin = ""
        in_power = 0
    }

    in_power && /^[[:space:]]*id[[:space:]]*=/ {
        power_id = clean($0)
        next
    }

    in_power && /^[[:space:]]*origin[[:space:]]*=/ {
        power_origin = clean($0)
        next
    }

    END {
        emit_power()
    }
    ' "${kit_file}"
}


# =============================================================================
# Formula / Cask kit writer
#
# Rebuilds the complete kit while preserving Powers.
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
    local powers=()

    local existing
    local power_id
    local power_origin

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

    while IFS=$'\t' read -r power_id power_origin; do
        [[ -n "${power_id}" ]] || continue

        powers+=("${power_id}"$'\t'"${power_origin}")

    done < <(
        cybercats_cckit_read_powers_raw \
            "${kit_file}"
    )

    if [[ "${operation}" == "add" ]]; then

        if [[ "${section}" == "formulae" ]]; then
            formulae+=("${package}")
        else
            casks+=("${package}")
        fi

    fi

    cybercats_cckit_write_kit \
        "${kit_file}" \
        "${kit_name}" \
        formulae \
        casks \
        powers
}


# =============================================================================
# Power kit writer
# =============================================================================

cybercats_cckit_rewrite_power_in_kit() {
    local kit_file="${1}"
    local operation="${2}"
    local requested_power_id="${3}"
    local requested_power_origin="${4}"

    local kit_name
    kit_name="$(basename "${kit_file}" .toml)"

    local formulae=()
    local casks=()
    local powers=()

    local existing
    local power_id
    local power_origin

    while IFS= read -r existing; do
        [[ -n "${existing}" ]] || continue
        formulae+=("${existing}")

    done < <(
        cybercats_cckit_read_kit_entries_raw \
            "${kit_file}" \
            "formulae"
    )

    while IFS= read -r existing; do
        [[ -n "${existing}" ]] || continue
        casks+=("${existing}")

    done < <(
        cybercats_cckit_read_kit_entries_raw \
            "${kit_file}" \
            "casks"
    )

    while IFS=$'\t' read -r power_id power_origin; do
        [[ -n "${power_id}" ]] || continue

        # Remove the existing record if we are either deleting it
        # or replacing it with newer origin metadata.
        if [[ "${power_id}" == "${requested_power_id}" ]]; then
            continue
        fi

        powers+=("${power_id}"$'\t'"${power_origin}")

    done < <(
        cybercats_cckit_read_powers_raw \
            "${kit_file}"
    )

    if [[ "${operation}" == "add" ]]; then
        powers+=(
            "${requested_power_id}"$'\t'"${requested_power_origin}"
        )
    fi

    cybercats_cckit_write_kit \
        "${kit_file}" \
        "${kit_name}" \
        formulae \
        casks \
        powers
}


# =============================================================================
# Complete kit writer
# =============================================================================

cybercats_cckit_write_kit() {
    local kit_file="${1}"
    local kit_name="${2}"
    local formulae_array_name="${3}"
    local casks_array_name="${4}"
    local powers_array_name="${5}"

    eval 'local formulae=("${'"${formulae_array_name}"'[@]}")'
    eval 'local casks=("${'"${casks_array_name}"'[@]}")'
    eval 'local powers=("${'"${powers_array_name}"'[@]}")'

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

    local power_record
    local power_id
    local power_origin

    for power_record in "${powers[@]}"; do

        power_id="${power_record%%$'\t'*}"
        power_origin="${power_record#*$'\t'}"

        cybercats_cckit_write_power \
            "${kit_file}" \
            "${power_id}" \
            "${power_origin}"

    done
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


cybercats_cckit_write_power() {
    local output="${1}"
    local power_id="${2}"
    local power_origin="${3}"

    local escaped_id="${power_id//\\/\\\\}"
    escaped_id="${escaped_id//\"/\\\"}"

    local escaped_origin="${power_origin//\\/\\\\}"
    escaped_origin="${escaped_origin//\"/\\\"}"

    cat >> "${output}" <<EOF

[[powers]]
id = "${escaped_id}"
origin = "${escaped_origin}"
EOF
}