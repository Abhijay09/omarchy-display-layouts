#!/bin/bash
# Windows Win+P style layouts: extend-right | extend-left | mirror | tv | laptop
mode=$1
INT=$(omarchy-hyprland-monitor-laptop)
EXT=$(hyprctl monitors all -j | jq -r '[.[] | select(.name | test("^(eDP|LVDS|DSI)-") | not)][0].name // empty')

if [[ -z $EXT ]]; then
  omarchy-notification-send -g 󰍹 "No external display connected"
  exit 1
fi
for o in "$INT" "$EXT"; do
  [[ $o =~ ^[A-Za-z0-9._-]+$ ]] || { omarchy-notification-send -g 󰍹 "Refusing unsafe monitor name"; exit 1; }
done

ext_on() { hyprctl eval "hl.monitor({ output = \"$EXT\", disabled = false, mode = \"preferred\", position = \"$1\", scale = \"auto\" })" >/dev/null; }

case "$mode" in
  extend-right|extend-left)
    omarchy-hyprland-monitor-internal-mirror off
    omarchy-hyprland-monitor-internal on
    ext_on "auto-${mode#extend-}"
    omarchy-notification-send -g 󰍹 "Extended: $EXT on the ${mode#extend-}"
    ;;
  mirror)
    omarchy-hyprland-monitor-internal-mirror on
    ;;
  tv)
    omarchy-hyprland-monitor-internal-mirror off
    ext_on auto
    omarchy-hyprland-monitor-internal off
    ;;
  laptop)
    omarchy-hyprland-monitor-internal-mirror off
    omarchy-hyprland-monitor-internal on
    hyprctl eval "hl.monitor({ output = \"$EXT\", disabled = true })" >/dev/null
    omarchy-notification-send -g 󰍹 "Laptop display only"
    ;;
  *) echo "usage: $0 extend-right|extend-left|mirror|tv|laptop" >&2; exit 1 ;;
esac
