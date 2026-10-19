# App Store listing: ubu

Copy-paste values for App Store Connect. Character limits are checked by
`Distribution/AppStore/check-listing.sh`.

## App information

| Field | Value |
|---|---|
| Name | ubu: Dock Lock |
| Subtitle | Keep the Dock on one display |
| Bundle ID | com.fluxscale.ubu |
| Apple ID (App Store Connect) | 6824554076 |
| SKU | ubu-mac |
| Primary category | Utilities |
| Secondary category | Productivity |
| Content rights | Does not contain third-party content |
| Age rating | 4+ (answer "None" to every question) |
| Privacy policy URL | https://github.com/fluxscale/ubu/blob/main/PRIVACY.md |
| Support URL | https://github.com/fluxscale/ubu/issues |
| Marketing URL | https://github.com/fluxscale/ubu |
| Copyright | 2026 Fluxscale Limited |

## Promotional text

<!-- promo -->
Using more than one display? ubu stops macOS from moving your Dock whenever the pointer brushes the bottom of another screen.
<!-- /promo -->

## Description

<!-- description -->
macOS moves the Dock to whichever display you push the pointer against. Brush the bottom of a second monitor and the Dock jumps there. There is no setting to turn this off.

ubu turns it off. It sits in the menu bar and keeps the Dock on your main display.

HOW IT WORKS
• When the pointer rests against the Dock edge of another display, ubu nudges it a few points back, before macOS can move the Dock.
• If the Dock moves anyway (a fast flick, waking from sleep, plugging in a monitor), ubu brings it straight back. No Dock restart, no flicker.
• Edges where one display continues into another are left alone, so the pointer moves freely between your monitors.

DESIGNED TO STAY OUT OF THE WAY
• Works with any number of displays, and with the Dock at the bottom, left, or right
• Never interrupts a drag
• Pause from the menu bar whenever you want the Dock to follow you again
• Optional launch at login
• Uses about 14 MB of memory and no measurable CPU while idle

PRIVATE BY DESIGN
ubu collects nothing. No accounts, no analytics, no network requests of its own. It needs the Accessibility permission to see and move the pointer, and that information never leaves your Mac.

SUBSCRIPTION
ubu is $4.99 a year, with a free trial. Payment is charged to your Apple Account when you confirm the purchase. The subscription renews automatically unless you cancel at least 24 hours before the end of the current period. Manage or cancel it in your App Store account settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://github.com/fluxscale/ubu/blob/main/PRIVACY.md
<!-- /description -->

## Keywords

<!-- keywords -->
dock,display,monitor,multiple,screen,external,lock,stop,jumping,menu bar,multi-monitor,utility
<!-- /keywords -->

## What's New (first release)

<!-- whatsnew -->
First App Store release.
<!-- /whatsnew -->

## Subscription

| Field | Value |
|---|---|
| Subscription group | ubu |
| Reference name | ubu Yearly |
| Product ID | com.fluxscale.ubu.yearly |
| Duration | 1 year |
| Price | $4.99 (USD base; let Apple set other storefronts) |
| Introductory offer | Free, 1 week, new subscribers |
| Display name | ubu Yearly |
| Description | Keep your Dock on your main display. |
| Review screenshot | The ubu menu showing "Start Free Trial…" (see README step 9) |

## App Review notes

<!-- review -->
ubu keeps the macOS Dock on the user's main display. macOS moves the Dock to any display whose bottom edge the pointer pushes against; ubu prevents that.

ACCESSIBILITY
ubu asks for the Accessibility permission, and only uses it for this:
1. An event tap watches pointer movement. When the pointer has rested against the Dock edge of a secondary display for 0.1 seconds, ubu moves it 6 points back onto that display (CGWarpMouseCursorPosition), so macOS never moves the Dock.
2. If the Dock still ends up on another display, ubu posts a short synthetic pointer movement against the main display's bottom edge, which is exactly what a user does by hand to move the Dock back. This is limited to three attempts, never happens during a drag, and returns the pointer to where it was.
ubu does not read keystrokes, other apps' content, or anything other than pointer position and the Dock's window position. Nothing is stored or sent.

HOW TO TEST
This needs two displays (an external monitor, or an iPad via Sidecar).
1. Launch ubu. A paw print appears in the menu bar. Grant Accessibility when asked.
2. Choose "Start Free Trial…" from the menu and complete the sandbox purchase.
3. Push the pointer firmly against the bottom edge of the secondary display. Without ubu the Dock moves there; with ubu it stays on the main display.
4. Choose "Pause Anchoring" and repeat: the Dock moves again, as in standard macOS.
A screen recording of these steps is attached.

No sign-in is required. Launch at login is off until the user enables it from the menu.
<!-- /review -->
