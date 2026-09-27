#!/bin/sh
# Mirror ~/.config/gtk-3.0/settings.ini into gsettings -- port of the Hyprland
# rice's hypr/scripts/gtk.sh (run at login). libadwaita apps (nautilus, loupe,
# gnome-text-editor, gnome-calculator) ignore settings.ini/xsettingsd and
# follow org.gnome.desktop.interface color-scheme; matugen's
# gtk-themes-reload.sh post_hook also toggles from its current value.
command -v gsettings >/dev/null 2>&1 || exit 0
config="$HOME/.config/gtk-3.0/settings.ini"
[ -f "$config" ] || exit 1
get() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$config" | head -n 1; }
schema=org.gnome.desktop.interface
case "$(get gtk-application-prefer-dark-theme)" in
    0|false) scheme=prefer-light ;;
    *) scheme=prefer-dark ;;
esac
gsettings set $schema gtk-theme "$(get gtk-theme-name)"
gsettings set $schema icon-theme "$(get gtk-icon-theme-name)"
gsettings set $schema cursor-theme "$(get gtk-cursor-theme-name)"
gsettings set $schema cursor-size "$(get gtk-cursor-theme-size)"
gsettings set $schema font-name "$(get gtk-font-name)"
gsettings set $schema color-scheme "$scheme"
