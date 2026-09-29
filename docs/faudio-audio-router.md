# `faudio` — Interactive PipeWire Per-App Sink Switcher

## Purpose
Route any running audio stream to any output device (speakers, headphones, HDMI, Bluetooth A2DP) without leaving the terminal or opening a GUI mixer. Uses `wpctl` (WirePlumber native) with `pactl` as fallback.

## Usage

```bash
faudio
```

1. A list of active audio streams (apps playing audio) appears in `fzf`
2. Select a stream → press `Enter`
3. A list of available output sinks appears
4. Select a sink → stream is re-routed instantly

**`Ctrl-R`** in the stream picker restarts `wireplumber`, `pipewire`, and `pipewire-pulse` (useful after Bluetooth device reconnect).

## Where It Lives
- Added to `dotfiles/.zshrc` — Section 12

## Dependencies
- `wpctl` (WirePlumber — preferred) or `pactl` (pipewire-pulse)
- `fzf`
- `column` (util-linux, always present)

## Notes
- PipeWire stream IDs are **ephemeral** — parsed fresh every invocation, never cached.
- If no streams are active (no app is playing audio), `faudio` exits with a helpful message.
- System-wide default sink is changed separately via `wpctl set-default <sink_id>`.
