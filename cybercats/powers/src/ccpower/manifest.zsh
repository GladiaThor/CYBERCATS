#!/usr/bin/env zsh

# =============================================================================
# CCPower
#
# CYBERCATS Power package manager.
#
# Framework flags such as:
#
#   --help
#   --description
#   --version
#   --source
#
# are implemented by the generated wrapper.
# And before you ask, yes this power did kind of create the wrapper for itself,
# and that's how I know it works. 
# =============================================================================


# =============================================================================
# Entrypoint
# =============================================================================

cybercats_ccpower() {
    local command="${1:-}"

    case "${command}" in

        install)
            shift
            cybercats_ccpower_install "$@"
            ;;

        remove)
            shift
            cybercats_ccpower_remove "$@"
            ;;

        list)
            shift
            cybercats_ccpower_list "$@"
            ;;

        *)
            cybercats_ccpower_usage
            return 1
            ;;
    esac
}


# =============================================================================
# Install
# =============================================================================

cybercats_ccpower_install() {
    local repository="${1:-}"

    if [[ -z "${repository}" ]]; then
        echo "Usage:"
        echo "  ccpower install <git repository>"
        return 1
    fi

    local powers_root="${CYBERCATS_HOME}/powers"
    local src_root="${powers_root}/src"
    local installed_root="${powers_root}/installed"
    local builtins_root="${powers_root}/builtins"

    local temp_directory

    temp_directory="$(mktemp -d "${TMPDIR:-/tmp}/ccpower.XXXXXX")" || {
        echo "ERROR: Unable to create temporary directory."
        return 1
    }

    # Always clean the temporary clone.
    trap 'rm -rf "${temp_directory}"' EXIT INT TERM

    echo
    echo "Fetching Power:"
    echo "  ${repository}"
    echo

    if ! git clone --quiet "${repository}" "${temp_directory}/repo"; then
        echo "ERROR: Unable to clone repository."
        return 1
    fi

    local repository_directory="${temp_directory}/repo"
    local manifest="${repository_directory}/power.toml"

    if [[ ! -f "${manifest}" ]]; then
        echo "ERROR: Repository does not contain power.toml."
        return 1
    fi

    # -------------------------------------------------------------------------
    # Read manifest
    # -------------------------------------------------------------------------

    local power_id
    local power_name
    local power_version
    local power_description
    local entrypoint_file
    local entrypoint_function

    power_id="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" \
            "" \
            "id"
    )"

    power_name="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" \
            "" \
            "name"
    )"

    power_version="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" \
            "" \
            "version"
    )"

    power_description="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" \
            "" \
            "description"
    )"

    entrypoint_file="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" \
            "entrypoint" \
            "file"
    )"

    entrypoint_function="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" \
            "entrypoint" \
            "function"
    )"

    # -------------------------------------------------------------------------
    # Validate manifest
    # -------------------------------------------------------------------------

    if [[ -z "${power_id}" ]]; then
        echo "ERROR: power.toml does not define an id."
        return 1
    fi

    if [[ ! "${power_id}" =~ '^[a-z][a-z0-9_]*$' ]]; then
        echo "ERROR: Power id must be snake_case:"
        echo "  ${power_id}"
        return 1
    fi

    if [[ -z "${power_name}" ]]; then
        echo "ERROR: power.toml does not define a name."
        return 1
    fi

    if [[ -z "${entrypoint_file}" ]]; then
        echo "ERROR: power.toml does not define entrypoint.file."
        return 1
    fi

    if [[ -z "${entrypoint_function}" ]]; then
        echo "ERROR: power.toml does not define entrypoint.function."
        return 1
    fi

    if [[ ! "${entrypoint_function}" =~ '^[a-zA-Z_][a-zA-Z0-9_]*$' ]]; then
        echo "ERROR: Invalid entrypoint function:"
        echo "  ${entrypoint_function}"
        return 1
    fi

    if [[ ! -f "${repository_directory}/${entrypoint_file}" ]]; then
        echo "ERROR: Entrypoint file does not exist:"
        echo "  ${entrypoint_file}"
        return 1
    fi

    local source_directory="${src_root}/${power_id}"
    local installed_wrapper="${installed_root}/${power_id}.zsh"
    local builtin_wrapper="${builtins_root}/${power_id}.zsh"

    # -------------------------------------------------------------------------
    # Collision checks
    # -------------------------------------------------------------------------

    if [[ -f "${builtin_wrapper}" ]]; then
        echo "ERROR: '${power_id}' is a built-in CYBERCATS Power."
        echo "It cannot be replaced by an installed Power."
        return 1
    fi

    if [[ -d "${source_directory}" || -f "${installed_wrapper}" ]]; then
        echo "ERROR: Power is already installed:"
        echo "  ${power_id}"
        echo
        echo "Remove it before installing it again."
        return 1
    fi

    # -------------------------------------------------------------------------
    # Install source
    # -------------------------------------------------------------------------

    echo "Installing ${power_name}..."

    mkdir -p "${source_directory}"
    mkdir -p "${installed_root}"

    # Copy the repository contents exactly, including dotfiles.
    cp -R "${repository_directory}/." "${source_directory}/"

    # We don't need the Power's Git metadata after installation.
    rm -rf "${source_directory}/.git"

    # -------------------------------------------------------------------------
    # Generate wrapper
    # -------------------------------------------------------------------------

    if ! cybercats_ccpower_generate_wrapper \
        "${source_directory}/power.toml" \
        "${installed_wrapper}"
    then
        echo "ERROR: Failed to generate Power wrapper."

        rm -rf "${source_directory}"
        rm -f "${installed_wrapper}"

        return 1
    fi

    echo
    echo "✓ ${power_name} ${power_version} installed."
    echo "  ${source_directory}"
    echo

    # Make the Power available immediately in the current shell.
    source "${installed_wrapper}"

    trap - EXIT INT TERM
    rm -rf "${temp_directory}"
}


# =============================================================================
# Remove
# =============================================================================

cybercats_ccpower_remove() {
    local power_id="${1:-}"

    if [[ -z "${power_id}" ]]; then
        echo "Usage:"
        echo "  ccpower remove <power>"
        return 1
    fi

    local powers_root="${CYBERCATS_HOME}/powers"

    local source_directory="${powers_root}/src/${power_id}"
    local installed_wrapper="${powers_root}/installed/${power_id}.zsh"
    local builtin_wrapper="${powers_root}/builtins/${power_id}.zsh"

    if [[ -f "${builtin_wrapper}" ]]; then
        echo "ERROR: '${power_id}' is a built-in CYBERCATS Power."
        echo "Built-in Powers cannot be removed."
        return 1
    fi

    if [[ ! -d "${source_directory}" && ! -f "${installed_wrapper}" ]]; then
        echo "Power is not installed:"
        echo "  ${power_id}"
        return 1
    fi

    rm -rf "${source_directory}"
    rm -f "${installed_wrapper}"

    # Remove the function from the current shell if it exists.
    unfunction "${power_id}" 2>/dev/null || true

    echo "✓ ${power_id} removed."
}


# =============================================================================
# List
# =============================================================================

cybercats_ccpower_list() {
    local powers_root="${CYBERCATS_HOME}/powers"

    echo
    echo "CYBERCATS Powers"
    echo "================"
    echo

    local wrapper
    local power_id

    echo "Built-in:"

    for wrapper in "${powers_root}/builtins"/*.zsh(N); do
        power_id="$(basename "${wrapper}" .zsh)"
        echo "  ${power_id}"
    done

    echo
    echo "Installed:"

    local found=false

    for wrapper in "${powers_root}/installed"/*.zsh(N); do
        power_id="$(basename "${wrapper}" .zsh)"
        echo "  ${power_id}"
        found=true
    done

    if [[ "${found}" == false ]]; then
        echo "  None"
    fi

    echo
}


# =============================================================================
# Wrapper generator
# =============================================================================

cybercats_ccpower_generate_wrapper() {
    local manifest="${1}"
    local output="${2}"

    local power_id
    local power_name
    local power_version
    local power_description
    local entrypoint_file
    local entrypoint_function
    local aliases

    power_id="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" "" "id"
    )"

    power_name="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" "" "name"
    )"

    power_version="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" "" "version"
    )"

    power_description="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" "" "description"
    )"

    entrypoint_file="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" "entrypoint" "file"
    )"

    entrypoint_function="$(
        cybercats_ccpower_manifest_value \
            "${manifest}" "entrypoint" "function"
    )"

    aliases="$(
        cybercats_ccpower_manifest_aliases "${manifest}"
    )"

    local variables_help

    variables_help="$(
        cybercats_ccpower_manifest_variables_help "${manifest}"
    )"

    local source_directory="${manifest:h}"

    cat > "${output}" <<EOF
# =============================================================================
# GENERATED BY CYBERCATS
#
# Power: ${power_name}
# ID: ${power_id}
#
# Do not edit this file directly.
# =============================================================================

${power_id}() {

    case "\${1:-}" in

        --help|-h)
            cat <<'POWER_HELP'
${power_name}

${power_description}

Version:
  ${power_version}

Usage:
  ${power_id} [arguments]

Framework commands:
  --help
      Show this help.

  --description
      Show the Power description.

  --version
      Show the installed Power version.

  --source
      Show the full path to the Power source.

${variables_help}
POWER_HELP
            return 0
            ;;

        --description)
            echo "${power_description}"
            return 0
            ;;

        --version)
            echo "${power_name} ${power_version}"
            return 0
            ;;

        --source)
            echo "${source_directory}"
            return 0
            ;;

        *)
            if ! typeset -f "${entrypoint_function}" >/dev/null 2>&1; then
                source "${source_directory}/${entrypoint_file}" || return 1
            fi

            ${entrypoint_function} "\$@"
            ;;
    esac
}

EOF

    local alias_name

    while IFS= read -r alias_name; do

        [[ -z "${alias_name}" ]] && continue

        if [[ ! "${alias_name}" =~ '^[a-zA-Z_][a-zA-Z0-9_-]*$' ]]; then
            echo "ERROR: Invalid Power alias:"
            echo "  ${alias_name}"
            return 1
        fi

        cat >> "${output}" <<EOF
function ${alias_name} {
    ${power_id} "\$@"
}

EOF

    done <<< "${aliases}"
}


# =============================================================================
# Minimal manifest reader
#
# CYBERCATS intentionally supports a small TOML subset for Power manifests.
#
# This prevents the core installer from requiring another package purely to
# understand its own metadata.
# =============================================================================

cybercats_ccpower_manifest_value() {
    local manifest="${1}"
    local requested_section="${2}"
    local requested_key="${3}"

    awk \
        -v requested_section="${requested_section}" \
        -v requested_key="${requested_key}" \
        '
        function trim(value) {
            gsub(/^[[:space:]]+/, "", value)
            gsub(/[[:space:]]+$/, "", value)
            return value
        }

        BEGIN {
            section = ""
        }

        /^[[:space:]]*#/ {
            next
        }

        /^[[:space:]]*\[\[/ {
            section = "__array__"
            next
        }

        /^[[:space:]]*\[/ {
            line = $0

            gsub(/^[[:space:]]*\[/, "", line)
            gsub(/\][[:space:]]*$/, "", line)

            section = trim(line)
            next
        }

        {
            if (section != requested_section) {
                next
            }

            equals = index($0, "=")

            if (!equals) {
                next
            }

            key = trim(substr($0, 1, equals - 1))

            if (key != requested_key) {
                next
            }

            value = trim(substr($0, equals + 1))

            if (
                substr(value, 1, 1) == "\"" &&
                substr(value, length(value), 1) == "\""
            ) {
                value = substr(value, 2, length(value) - 2)
            }

            print value
            exit
        }
        ' "${manifest}"
}


# =============================================================================
# Aliases
#
# v1 Power manifests intentionally require aliases to be declared on one line:
#
# aliases = ["tps", "searchdocs"]
# =============================================================================

cybercats_ccpower_manifest_aliases() {
    local manifest="${1}"

    local raw

    raw="$(
        awk '
        /^[[:space:]]*aliases[[:space:]]*=/ {
            sub(/^[^=]*=[[:space:]]*/, "")
            print
            exit
        }
        ' "${manifest}"
    )"

    [[ -z "${raw}" ]] && return 0

    raw="${raw#[}"
    raw="${raw%]}"

    echo "${raw}" |
        tr ',' '\n' |
        sed \
            -e 's/^[[:space:]]*//' \
            -e 's/[[:space:]]*$//' \
            -e 's/^"//' \
            -e 's/"$//'
}


# =============================================================================
# Variables -> generated help
# =============================================================================

cybercats_ccpower_manifest_variables_help() {
    local manifest="${1}"

    awk '
    function trim(value) {
        gsub(/^[[:space:]]+/, "", value)
        gsub(/[[:space:]]+$/, "", value)
        return value
    }

    function clean(value) {
        value = trim(value)

        if (
            substr(value, 1, 1) == "\"" &&
            substr(value, length(value), 1) == "\""
        ) {
            value = substr(value, 2, length(value) - 2)
        }

        return value
    }

    function print_variable() {

        if (name == "") {
            return
        }

        if (!printed_header) {
            print "Variables:"
            printed_header = 1
        }

        print "  " name

        if (description != "") {
            print "      " description
        }

        if (required == "true") {
            print "      Required."
        }

        if (default_value != "") {
            print "      Default: " default_value
        }

        print ""
    }

    BEGIN {
        in_variable = 0
        printed_header = 0
    }

    /^[[:space:]]*\[\[variables\]\]/ {

        if (in_variable) {
            print_variable()
        }

        name = ""
        description = ""
        required = ""
        default_value = ""

        in_variable = 1
        next
    }

    /^[[:space:]]*\[/ {

        if (in_variable) {
            print_variable()
            in_variable = 0
        }

        next
    }

    {
        if (!in_variable) {
            next
        }

        equals = index($0, "=")

        if (!equals) {
            next
        }

        key = trim(substr($0, 1, equals - 1))
        value = clean(substr($0, equals + 1))

        if (key == "name") {
            name = value
        }

        if (key == "description") {
            description = value
        }

        if (key == "required") {
            required = value
        }

        if (key == "default") {
            default_value = value
        }
    }

    END {
        if (in_variable) {
            print_variable()
        }
    }
    ' "${manifest}"
}


# =============================================================================
# Usage
# =============================================================================

cybercats_ccpower_usage() {
    cat <<'EOF'
CCPower

Manage CYBERCATS Powers.

Commands:

  ccpower install <git repository>
      Install a Power from a Git repository.

  ccpower remove <power>
      Remove an installed Power.

  ccpower list
      List built-in and installed Powers.

Examples:

  ccpower install https://github.com/example/power-search.git

  ccpower remove power_search

  ccpower list
EOF
}