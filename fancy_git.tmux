#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

git_status="#($CURRENT_DIR/scripts/fancy_git.sh)"
placeholder="\#{fancy_git}"

update_tmux_option() {
  local option="$1"
  local option_value=$(tmux show-option -gqv "$option")
  local new_option_value="$(do_interpolation "$option_value")"
  tmux set-option -gq "$option" "$new_option_value"
}

do_interpolation() {
    local string="$1"
    local interpolated="${string/$placeholder/$git_status}"
    echo "$interpolated"
}

main() {
  update_tmux_option "status-left"
  update_tmux_option "status-right"
}

main
