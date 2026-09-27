#!/bin/sh
# Start (or restart) the Quickshell shell -- run by the i3 config's
# exec_always and SUPER+SHIFT+B. `qs kill` stops the running instance first,
# so an i3 restart or the keybinding restarts the shell instead of stacking a
# second bar. Icons: kora like the Hyprland rice (QS_ICON_THEME comes from
# ~/.xsessionrc), Papirus-Dark when kora isn't installed. Logs: `qs log`
# (Quickshell keeps them itself).
qs kill >/dev/null 2>&1
if [ -z "$QS_ICON_THEME" ] || [ ! -d "/usr/share/icons/$QS_ICON_THEME" ]; then
    if [ -d /usr/share/icons/kora ]; then QS_ICON_THEME=kora; else QS_ICON_THEME=Papirus-Dark; fi
fi
QS_ICON_THEME=$QS_ICON_THEME exec quickshell >/dev/null 2>&1
