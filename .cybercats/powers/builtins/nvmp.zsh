neovim_plugin_config() {
  local plugin=""
  local flag=""
  local plugin_dir="$HOME/.config/nvim/lua/plugins"
  local archive_dir="$plugin_dir/archive"
  
  local general_flags=(
    "-l" 
    "-list"
  )

  power_dir "$archive_dir"

  for arg in "$@"; do
    case "$arg" in
      -*)
        flag="$arg"
        ;;
      *)
        plugin="$arg"
        ;;
    esac
  done

  contains() {
    local match="$1"
    shift

    for item in "$@"; do
      [ "$item" = "$match" ] && return 0
    done

    return 1
  }

  if [ -z "$plugin" ] && ! contains "$flag" "${general_flags[@]}"; then
    echo "Usage:"
    echo "  nvmp <plugin>       # Open plugin config file"
    echo "  nvmp -a <plugin>    # Archive plugin"
    echo "  nvmp -u <plugin>    # Unarchive plugin"
    echo "  nvmp -l             # List all plugins"
    return 1
  fi


  case "$flag" in
    -a)
      mv "$plugin_dir/$plugin.lua" "$archive_dir/"
      echo "Archived $plugin.lua"
      ;;
    -l)
	    echo "===Installed==="
      for plugin in "$plugin_dir"/*.lua(N);do
        echo "${plugin:t:r}"
      done
	    echo "===Archived==="
      for plugin in "$archived_dir"/*.lua(N);do
        echo "${plugin:t:r}"
      done
	    ;;
    -u)
      mv "$archive_dir/$plugin.lua" "$plugin_dir/"
      echo "Unarchived $plugin.lua"
      ;;
    *)
      nvim "$plugin_dir/$plugin.lua"
      ;;
  esac
}

alias nvmp=neovim_plugin_config
