# Fractal

Fractal is a native macOS menu bar focus tool for short, precise work blocks. It uses a status item, a SwiftUI popover, a native completion panel, and local JSON history storage.

## Requirements

- macOS 13 or newer
- Xcode 15 or newer, or the matching Swift toolchain on macOS

## Run

Open this folder in Xcode and run the `Fractal` executable target.

You can also run it from Terminal on macOS:

```sh
swift run Fractal
```

To create a menu-bar-only app bundle:

```sh
bash Scripts/package-app.sh
open .build/release/Fractal.app
```

The app runs as an accessory app, so it lives in the menu bar instead of the Dock. Completed sessions are saved to:

```text
~/Library/Application Support/Fractal/sessions.json
```

## Features

- Live menu bar countdown while a block is active
- Popover timer with topic entry, Start, Pause, and Reset
- Native completion popup with sound, Continue, Switch, and Log Only actions
- Automatic history with topic, exact configured duration, start time, and end time
- Today and this-week focused-time totals
- Settings for block length, sound, auto-start behavior, and menu bar seconds
