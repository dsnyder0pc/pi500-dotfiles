# Linux version of macOS pbcopy and pbpaste (dynamic fallback for headless/Wayland/X11/WSL2 compatibility)
if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy &>/dev/null; then
    alias pbcopy='wl-copy'
    alias pbpaste='wl-paste'
elif [ -n "$DISPLAY" ] && command -v xclip &>/dev/null; then
    alias pbcopy='xclip -selection clipboard'
    alias pbpaste='xclip -selection clipboard -o'
elif { [ -n "$WSL_DISTRO_NAME" ] || grep -qiq microsoft /proc/version 2>/dev/null; } && \
     command -v clip.exe &>/dev/null && command -v powershell.exe &>/dev/null; then
    # WSL2 Clipboard Integration
    alias pbcopy='clip.exe'
    alias pbpaste='powershell.exe -noprofile -command "Get-Clipboard" | tr -d "\r"'
elif [ -n "$TMUX" ]; then
    alias pbcopy='tmux load-buffer -'
    alias pbpaste='tmux save-buffer -'
else
    pbcopy() {
        cat > ~/.clipboard
        echo "Copied to ~/.clipboard (headless fallback)" >&2
    }
    pbpaste() {
        if [ -f ~/.clipboard ]; then
            cat ~/.clipboard
        else
            echo "Error: ~/.clipboard does not exist" >&2
            return 1
        fi
    }
fi

# Launch Antigravity TUI in a tmux floating popup window
alias agy-pop='tmux display-popup -E -w 85% -h 85% agy'
