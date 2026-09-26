# -----------------------------------------------------
# ALIASES
# -----------------------------------------------------
source ~/.config/xcloud/scripts/xcloud-shell-aliases

# -----------------------------------------------------
# aiOS
# -----------------------------------------------------
function aios-code
    set -l url http://127.0.0.1:3901
    set -l bin (find /opt/aios/opencode/node_modules/.pnpm -maxdepth 6 -path '*opencode-linux-x64/bin/opencode' -type f 2>/dev/null | head -1)
    if test -z "$bin"; or not test -x "$bin"
        echo "aios-code: pinned opencode binary not found under /opt/aios/opencode" >&2
        return 1
    end
    set -l pw (sudo grep -oP 'AIOS_OPENCODE_SERVER_PASSWORD=\K.*' /opt/aios/config/aios.env)
    if test -z "$pw"
        echo "aios-code: could not read AIOS_OPENCODE_SERVER_PASSWORD" >&2
        return 1
    end
    if test "$argv[1]" = "--continue"; or test "$argv[1]" = "--attach"
        set -e argv[1]
        env OPENCODE_SERVER_PASSWORD=$pw $bin attach $url --continue $argv
    else
        env OPENCODE_SERVER_PASSWORD=$pw $bin attach $url $argv
    end
end
