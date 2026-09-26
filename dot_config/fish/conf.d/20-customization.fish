# -----------------------------------------------------
# CUSTOMIZATION
# -----------------------------------------------------

# -----------------------------------------------------
# Prompt
# -----------------------------------------------------
# zen.toml uses named ANSI colors (blue/magenta/p:grey/...), not hex, so it
# already picks up live wallpaper-driven recoloring for free via kitty's own
# matugen-generated palette (colors-matugen.conf) -- no separate matugen
# template needed for this theme. The commented-out EDM115 alternative
# below is the one matugen/config.toml's [templates.ohmyposh] actually
# patches (hex-coded, via colors.json); it stays uncolored while inactive.
eval "$($HOME/.local/bin/oh-my-posh init fish --config $HOME/.config/ohmyposh/zen.toml)"
# eval "$($HOME/.local/bin/oh-my-posh init fish --config $HOME/.config/ohmyposh/EDM115-newline.omp.json)"

# -----------------------------------------------------
# Modern CLI Tooling
# -----------------------------------------------------
zoxide init fish | source
direnv hook fish | source
atuin init fish | source
