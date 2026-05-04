# ubu

macOS menubar daemon that keeps your Dock locked to your primary display.

macOS moves your Dock to whichever screen you push your cursor against the bottom edge of. There's no built-in setting to disable this. **ubu** fixes that.

## Install

### Download

Grab the latest `.dmg` from [Releases](https://github.com/fluxscale/ubu/releases), open it, and drag `ubu.app` to Applications.

### Build from source

```bash
git clone https://github.com/fluxscale/ubu.git
cd ubu
swift build -c release
# Binary at .build/release/ubu
```

### Create DMG

```bash
Distribution/DMG/create-dmg.sh 1.0.0
```

## Setup

1. Launch ubu — a paw print icon appears in your menubar
2. Grant Accessibility permission when prompted (System Settings > Privacy & Security > Accessibility)
3. Done. Your Dock stays put.

ubu starts at login automatically. Toggle this from the menubar menu.

## How it works

ubu uses three layers of defense:

| Layer | Mechanism | Role |
|-------|-----------|------|
| **Event Tap** | Intercepts mouse events at screen edges, warps cursor back | Prevents migration before it happens |
| **CoreDock** | Private framework via `dlopen` | Instant Dock repositioning if migration occurs |
| **Accessibility** | AX polling with burst mode on display changes | Safety net — catches anything the other layers miss |

All three layers use CG coordinates (`CGDisplayBounds`, `CGMainDisplayID`) for consistent screen geometry across the entire pipeline.

## Menubar

| Icon | State |
|------|-------|
| Filled paw | Active — Dock is anchored |
| Outline paw | Paused |
| Warning triangle | Needs Accessibility permission |

Menu options: Pause/Resume, Start at Login, Check for Updates, Quit.

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permission
- Works with any number of displays and all Dock positions (bottom, left, right)

## Updates

ubu checks GitHub Releases on launch and notifies you when a new version is available. You can also check manually from the menubar menu.

## Architecture

```
Sources/Ubu/
├── App/
│   ├── UbuApp.swift              # Entry point, lifecycle
│   ├── StatusBarController.swift # Menubar UI
│   └── PermissionManager.swift   # AX permission handling
├── Core/
│   ├── DisplayManager.swift      # Screen detection, edge zones
│   ├── EventTapLayer.swift       # Layer 1: cursor interception
│   ├── CoreDockBridge.swift      # Layer 2: private API bridge
│   ├── DockMonitor.swift         # Coordinator for all layers
│   └── AccessibilityLayer.swift  # Layer 3: AX polling
└── Utilities/
    ├── Logger.swift              # os_log wrapper
    ├── LoginItemManager.swift    # SMAppService wrapper
    └── UpdateChecker.swift       # GitHub Releases version check
```

## License

[MIT](LICENSE)
