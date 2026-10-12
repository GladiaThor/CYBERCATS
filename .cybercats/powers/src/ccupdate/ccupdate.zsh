
#!/usr/bin/env zsh

# =============================================================================
# CCUpdate
#
# CYBERCATS Update manager that makes sure the CYBERCAT installation is up to
# the latest version on the main branch,
# 
# NOTE: This is the first fully AI Generated feature in CYBERCAT. So we'll  
# see how much I'll regret this.
# =============================================================================

ccupdate() {
    emulate -L zsh
    setopt pipe_fail

    local root="${CC_ROOT:-$HOME/.cybercats}"
    local repo="${CC_REPO_URL:-https://github.com/GladiaThor/CYBERCATS.git}"
    local branch="${CC_REPO_BRANCH:-main}"

    local revision_file="$root/revision"
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cybercats"
    local cache_file="$cache_dir/latest-revision"
    local checked_file="$cache_dir/last-update-check"
    local lock_dir="$cache_dir/update-check.lock"

    local installed_revision=""
    local latest_revision=""
    local remote_line=""
    local now="$(date +%s)"
    local last_check=0

    [[ -d "$root" ]] || {
        print -u2 "Cybercats installation not found."
        return 1
    }

    command -v git >/dev/null 2>&1 || {
        print -u2 "Git is required to update Cybercats."
        return 1
    }

    [[ -f "$revision_file" ]] &&
        installed_revision="$(<"$revision_file")"

    mkdir -p "$cache_dir" || return 1

    # -----------------------------------------------
    # Check mode: lightweight, cached, non-blocking
    # -----------------------------------------------

    if [[ "${1:-}" == "--check" ]]; then

        # Announce an update found by a previous check.
        if [[ -f "$cache_file" ]]; then
            latest_revision="$(<"$cache_file")"

            if [[ -n "$latest_revision" &&
                  "$latest_revision" != "$installed_revision" ]]; then
                print -P "%F{magenta}🐈 Cybercats update available!%f Run %Bccupdate%b to upgrade."
            fi
        fi

        # Refresh the remote revision at most once per day.
        if [[ -f "$checked_file" ]]; then
            last_check="$(<"$checked_file")"
        fi

        [[ "$last_check" == <-> ]] || last_check=0

        (( now - last_check < 86400 )) && return 0

        # Run remotely without delaying shell startup.
        (
            # Reclaim a stale lock from an interrupted check.
            if [[ -d "$lock_dir" ]]; then
                local lock_time
                lock_time="$(stat -f %m "$lock_dir" 2>/dev/null ||
                             stat -c %Y "$lock_dir" 2>/dev/null)"
                [[ "$lock_time" == <-> ]] || lock_time=0

                if (( $(date +%s) - lock_time > 300 )); then
                    rmdir "$lock_dir" 2>/dev/null
                fi
            fi

            mkdir "$lock_dir" 2>/dev/null || exit 0
            trap 'rmdir "$lock_dir" 2>/dev/null' EXIT

            remote_line="$(
                GIT_TERMINAL_PROMPT=0 \
                git ls-remote "$repo" "refs/heads/$branch" 2>/dev/null
            )" || exit 0

            latest_revision="${remote_line%%$'\t'*}"

            [[ "$latest_revision" == [0-9a-f]## ]] || exit 0

            print -r -- "$latest_revision" > "$cache_file.tmp.$$"
            mv "$cache_file.tmp.$$" "$cache_file"

            print -r -- "$(date +%s)" > "$checked_file"
        ) >/dev/null 2>&1 &!

        return 0
    fi

    # -----------------------------------------------
    # Update mode: explicit installation
    # -----------------------------------------------

    if [[ -n "${1:-}" ]]; then
        print -u2 "Usage: ccupdate [--check]"
        return 2
    fi

    print "Checking for Cybercats updates..."

    remote_line="$(
        GIT_TERMINAL_PROMPT=0 \
        git ls-remote "$repo" "refs/heads/$branch"
    )" || {
        print -u2 "Unable to contact Cybercats repository."
        return 1
    }

    latest_revision="${remote_line%%$'\t'*}"

    [[ "$latest_revision" == [0-9a-f]## ]] || {
        print -u2 "Unable to determine remote revision."
        return 1
    }

    if [[ "$installed_revision" == "$latest_revision" ]]; then
        print "Cybercats is already up to date."
        return 0
    fi

    print "Updating Cybercats..."
    print "  Installed: ${installed_revision[1,8]:-unknown}"
    print "  Available: ${latest_revision[1,8]}"

    # Run deployment in a subshell so cleanup is guaranteed.
    (
        local temp_dir
        local source_root
        local wrapper
        local power_id
        local -a builtin_ids

        temp_dir="$(mktemp -d)" || exit 1
        trap 'rm -rf -- "$temp_dir"' EXIT

        # Shallow checkout at the exact remote revision.
        git -c advice.detachedHead=false clone \
            --quiet \
            --depth 1 \
            --filter=blob:none \
            --sparse \
            "$repo" "$temp_dir/repo" || exit 1

        git -C "$temp_dir/repo" fetch \
            --quiet --depth 1 origin "$latest_revision" || exit 1

        git -C "$temp_dir/repo" checkout \
            --quiet --detach "$latest_revision" || exit 1

        git -C "$temp_dir/repo" sparse-checkout set \
            .cybercats || exit 1

        source_root="$temp_dir/repo/.cybercats"

        # Validate the distribution before changing anything.
        [[ -f "$source_root/main.zsh" ]] || exit 1
        [[ -d "$source_root/powers/builtins" ]] || exit 1
        [[ -d "$source_root/powers/src" ]] || exit 1
        [[ -d "$source_root/visual" ]] || exit 1

        for wrapper in "$source_root"/powers/builtins/*.zsh(N); do
            power_id="${${wrapper:t}%.zsh}"
            builtin_ids+=("$power_id")

            [[ -d "$source_root/powers/src/$power_id" ]] || {
                print -u2 "Missing builtin source: $power_id"
                exit 1
            }
        done

        # Deploy main runtime.
        cp "$source_root/main.zsh" "$root/main.zsh" || exit 1

        # Synchronise Cybercats visual assets.
        mkdir -p "$root/visual" || exit 1

        rsync -a --delete \
            "$source_root/visual/" \
            "$root/visual/" || exit 1

        # Deploy sources belonging to builtin powers only.
        for power_id in "${builtin_ids[@]}"; do
            mkdir -p "$root/powers/src/$power_id" || exit 1

            rsync -a --delete \
                "$source_root/powers/src/$power_id/" \
                "$root/powers/src/$power_id/" || exit 1
        done

        # Synchronise builtin wrappers.
        mkdir -p "$root/powers/builtins" || exit 1

        rsync -a --delete \
            "$source_root/powers/builtins/" \
            "$root/powers/builtins/" || exit 1

        # Record the revision only after successful deployment.
        print -r -- "$latest_revision" > "$revision_file" ||
            exit 1

        # Synchronise the update-check cache.
        print -r -- "$latest_revision" > "$cache_file"
        print -r -- "$(date +%s)" > "$checked_file"

    ) || {
        print -u2 "Cybercats update failed."
        return 1
    }

    print ""
    print -P "%F{green}Cybercats updated successfully!%f"
    print "Revision: ${latest_revision[1,8]}"
    print "Restart your shell to load the changes."
}
