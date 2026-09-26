# -----------------------------------------------------
# AUTOSTART
# -----------------------------------------------------

# The 'y' command (Yazi, cd on exit)
function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# -----------------------------------------------------
# Fastfetch
# -----------------------------------------------------
if status is-interactive
    # Disable terminal auto-wrap (DECAWM) for the run so a line that's wider
    # than a narrow/tiled terminal (e.g. the cpu line's clock speed) clips
    # at the right edge instead of wrapping and breaking the box-drawing
    # layout onto a second row.
    printf '\e[?7l'; fastfetch; printf '\e[?7h'
end