# Publishing ubu on the Mac App Store

The App Store edition is the same app, built with `-DAPP_STORE`:

| | GitHub edition (DMG) | App Store edition |
|---|---|---|
| Bundle ID | `com.ubu.app` | `com.fluxscale.ubu` |
| Sandboxed | No | Yes |
| Price | Free | $0.99/year, 1-week free trial |
| Updates | Built-in GitHub check | App Store |
| Launch at login | On after first launch | Off until the user enables it |
| Dock side | Read from Dock prefs | Inferred from screen layout (prefs are sandbox-blocked) |

A sandboxed build was tested on macOS 26.5. Accessibility, the active event tap, pointer warping, event posting and window-list lookup all work under the App Sandbox.

Steps 1–8 are one-time setup and only the account holder can do them. After that, each release is step 10.

## 1. Agreements, tax and banking
[App Store Connect → Business](https://appstoreconnect.apple.com/business): accept the **Paid Apps** agreement and complete tax and banking. Subscriptions can't be sold until this shows _Active_.

Also apply to the [App Store Small Business Program](https://developer.apple.com/app-store/small-business-program/). Apple's commission drops from 30% to 15%, so a $0.99 subscription pays about $0.84 before tax.

## 2. App ID
[Certificates, Identifiers & Profiles → Identifiers → +](https://developer.apple.com/account/resources/identifiers/list) → App IDs → App:
- Description: `ubu`
- Bundle ID (explicit): `com.fluxscale.ubu`
- Capabilities: none extra. In-App Purchase is on by default.

## 3. Certificates
Xcode → Settings → Accounts → FLUXSCALE LIMITED → Manage Certificates → **+**:
- **Apple Distribution**
- **Mac Installer Distribution**

Check:
```bash
security find-identity -v | grep -E "Apple Distribution|3rd Party Mac Developer Installer"
```

## 4. Provisioning profile
[Profiles → +](https://developer.apple.com/account/resources/profiles/list) → **Mac App Store Connect** → App ID `com.fluxscale.ubu` → the Apple Distribution certificate → name it `ubu App Store` → download.

Save it as `Distribution/AppStore/ubu.provisionprofile` (git-ignored). The build script checks it matches the bundle ID.

## 5. The app record
[App Store Connect → Apps → + → New App](https://appstoreconnect.apple.com/apps): platform macOS, then the name, bundle ID and SKU from [LISTING.md](LISTING.md).

## 6. The subscription
In the app → Monetization → Subscriptions → create group **ubu** → create the subscription with the values in [LISTING.md](LISTING.md#subscription). The product ID must be exactly `com.fluxscale.ubu.yearly`, because the app looks it up by that ID. Add the 1-week free introductory offer.

## 7. Upload key (optional; Transporter works without it)
[Users and Access → Integrations → App Store Connect API → +](https://appstoreconnect.apple.com/access/integrations/api), role **App Manager**. Download the `.p8` once and put it at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`, then:
```bash
export ASC_KEY_ID=<key id>
export ASC_ISSUER_ID=<issuer id shown above the keys table>
```

## 8. A sandbox tester
Users and Access → Sandbox → Test Accounts → **+**. You'll use this to buy the subscription in TestFlight without being charged.

## 9. Screenshots and demo video
- At least one Mac screenshot at 2880×1800, 2560×1600, 1440×900 or 1280×800. Show the menu bar menu open over a two-display desktop.
- A short screen recording of the steps in the review notes. Reviewers often have one display, and the video saves a rejection round.
- The subscription needs its own review screenshot: the menu showing "Start Free Trial…".

## 10. Build, upload and submit
```bash
Distribution/AppStore/check-listing.sh                 # listing fits App Store limits
UPLOAD=1 Distribution/AppStore/build-appstore.sh 1.1.0  # build, sign, validate, upload
```
Without `UPLOAD=1`, drag `ubu-appstore.pkg` into Transporter instead.

Then in App Store Connect:
1. **TestFlight:** install the build on your Mac, sign in with the sandbox tester, and confirm the free trial unlocks ubu, Restore Purchases works, and Pause/Resume works.
2. **App Store tab:** fill in the listing from [LISTING.md](LISTING.md), attach the subscription to the version, answer App Privacy with **Data Not Collected**, paste the review notes and attach the video.
3. Submit for review.

## If App Review pushes back
The likely objection is guideline 2.4.5 (posting synthetic events). Two fallbacks keep the core feature, in order:
1. Point to the review notes: the posted events reproduce the gesture the user would make, are capped, and only bring the Dock back to the main display. [DockLock Lite](https://apps.apple.com/app/docklock-lite/id6741814079) ships the same kind of relocation on the Mac App Store.
2. Ship without correction. Prevention alone (event tap and warp) covers normal use. Remove the `onDockOnWrongScreen` wiring in `DockMonitor` for the `APP_STORE` build.
