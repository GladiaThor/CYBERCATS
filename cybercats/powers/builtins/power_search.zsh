thor_power_search() {
  local result file line
  result=$(rg --line-number --no-heading --color=always "$*" $DOCS_DIR -g "*.md" |
    fzf --ansi --delimiter ':' \
      --preview 'bat --style=numbers --color=always {1} --highlight-line {2}')

  file=$(echo "$result" | cut -d: -f1)
  line=$(echo "$result" | cut -d: -f2)

  [ -n "$file" ] && nvim +"$line" "$file"
}

alias tps=thor_power_search
