# Nyan Bar

A tiny macOS menu bar app that animates the original Nyan Cat GIF in your status bar.

## What it does

- Shows animated Nyan Cat directly in the macOS status bar.
- Runs fully offline (GIF is bundled into the `.app` at `Contents/Resources/original.gif`).
- Uses the first frame of Nyan Cat as the app icon (`Contents/Resources/AppIcon.icns`).
- Adds a menu with:
  - `Reload GIF`
  - `Quit Nyan Bar`
- Enables launch-at-login automatically on startup:
  - Uses `SMAppService` when available.
  - Falls back to a LaunchAgent (`~/Library/LaunchAgents/...`) when needed.

## Build + Run

```bash
swift build
swift run
```

## Build as a `.app`

```bash
./scripts/build_app.sh
open dist/NyanBar.app
```

## Install to `~/Applications` and launch

```bash
./scripts/install_app.sh
```

After the first run, Nyan Bar will register itself to run at login.
