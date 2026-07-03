# shellcheck shell=bash
# Linux version of macOS pbcopy and pbpaste using wl-clipboard (for Wayland compatibility)
alias pbcopy='wl-copy'
alias pbpaste='wl-paste'

# Launch Antigravity TUI in a tmux floating popup window
alias agy-pop='tmux display-popup -E -w 85% -h 85% agy'
