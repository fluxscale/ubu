<p align="center">
  <img src="Resources/ubu-logo.png" alt="ubu" width="200">
</p>

<h1 align="center">ubu</h1>

The menubar app that keeps your Dock locked when and where you want it.

macOS moves your Dock to whichever screen you push your cursor against the bottom edge of. There's no built-in setting to disable this. **ubu** fixes that.

<h2>Install</h2>

<h3>Download</h3>

Grab the latest `.dmg` from [Releases](https://github.com/fluxscale/ubu/releases), open it, and drag `ubu.app` to Applications.

Signed and notarized by Apple — no Gatekeeper warnings.

<h3>Build from source</h3>

```bash
git clone https://github.com/fluxscale/ubu.git
cd ubu
swift build -c release
# Binary at .build/release/ubu
```

<h3>Create DMG</h3>

```bash
Distribution/DMG/create-dmg.sh 1.0.0
```

<h2>Setup</h2>

1. Launch ubu — a paw print icon appears in your menubar
2. Grant Accessibility permission when prompted (System Settings > Privacy & Security > Accessibility)
3. Done. Your Dock stays put.

ubu starts at login automatically. Toggle this from the menubar menu.

<h2>How it works</h2>

ubu uses three layers of defense:

| Layer | Mechanism | Role |
|-------|-----------|------|
| **Event Tap** | Intercepts mouse events at screen edges, warps cursor back | Prevents migration before it happens |
| **CoreDock** | Private framework via `dlopen` | Instant Dock repositioning if migration occurs |
| **Accessibility** | AX polling with burst mode on display changes | Safety net — catches anything the other layers miss |

All three layers use CG coordinates (`CGDisplayBounds`, `CGMainDisplayID`) for consistent screen geometry across the entire pipeline.

<h2>Menubar</h2>

| Icon | State |
|------|-------|
| Filled paw | Active — Dock is anchored |
| Outline paw | Paused |
| Warning triangle | Needs Accessibility permission |

Menu options: Pause/Resume, Start at Login, Check for Updates, Quit.

<h2>Requirements</h2>

- macOS 13.0 (Ventura) or later
- Accessibility permission
- Works with any number of displays and all Dock positions (bottom, left, right)

<h2>Updates</h2>

ubu checks GitHub Releases on launch and notifies you when a new version is available. You can also check manually from the menubar menu.

<h2>Architecture</h2>

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

<h2>License</h2>

[MIT](LICENSE)
