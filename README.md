# Display Layouts

An Omarchy bar widget that adds Windows `Win+P` style layouts to the Display popup.

I use a laptop and a TV at the same time: a movie on the TV, work on the laptop.
Omarchy's Display widget can enable or disable screens, but there was no single
place to say "extend to the right" or "TV only". This is the stock widget with
a **LAYOUT** row added.

| Button | What it does |
| --- | --- |
| Extend → | TV becomes a second desktop to the right of the laptop |
| ← Extend | Same, but on the left |
| Mirror | Both screens show the same picture |
| TV only | Laptop screen off |
| Laptop only | External screen off |

Everything else (brightness, text size, scale, the DISPLAYS list) is unchanged.
With only one screen connected the buttons are dimmed.

## Install

```
omarchy plugin add https://github.com/Abhijay09/omarchy-display-layouts --enable
```

This widget **replaces** the built-in Display widget (it keeps the same
`omarchy.monitor` IPC target so the brightness keys keep working), so don't
enable both. If `--enable` doesn't swap it in on your bar, move it by hand:

```
omarchy bar move io.github.abhijay09.display-layouts --section right
```

## How it works

`layout.sh` finds the laptop panel and the first external output, then drives
Omarchy's own commands (`omarchy-hyprland-monitor-internal`,
`omarchy-hyprland-monitor-internal-mirror`) plus `hyprctl eval hl.monitor(...)`
for placement. It needs the Lua Hyprland config Omarchy ships now, since
`hyprctl keyword` is rejected there.

Layouts last for the session. A `hyprctl reload` or a reboot goes back to
Hyprland's default placement.

## Known issues

- Tested on one machine (Lenovo, Intel + NVIDIA hybrid). Other setups may need
  tweaks, and issues or PRs are welcome.
- **HDMI on hybrid-GPU laptops:** on many of these the HDMI port hangs off the
  NVIDIA GPU. If the GPU is in an integrated or VFIO mode (for example via
  `supergfxctl`), the TV gets no signal and Hyprland never sees the output.
  Switch to Hybrid mode and log back in. Hyprland only enumerates GPUs at
  startup, so a re-login is needed.
- The TV scale is `auto`. If it looks off, set one in the DISPLAYS section.
- No keyboard navigation for the LAYOUT buttons yet, mouse only.

## Credits

Based on `omarchy.monitor` from [Omarchy](https://github.com/omacom/omarchy) (MIT).

## License

MIT, see [LICENSE](LICENSE).
