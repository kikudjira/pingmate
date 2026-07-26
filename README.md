<img src="docs/screenshots/icon.png" align="left" height="72" alt="PingMate icon" />

# PingMate

**Know instantly whether your internet is the problem.**

[![Release](https://img.shields.io/github/v/release/kikudjira/pingmate?display_name=tag&sort=semver)](https://github.com/kikudjira/pingmate/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/kikudjira/pingmate/total)](https://github.com/kikudjira/pingmate/releases)
[![License](https://img.shields.io/github/license/kikudjira/pingmate)](LICENSE)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)

<br clear="left" />

<p align="center">
  <img src="docs/screenshots/popover.png" width="320" alt="PingMate popover showing latency, sparkline and stats" />
</p>

The call freezes, someone says *"you're breaking up"*, and nobody knows whose fault it is. PingMate has been watching the whole time: it pings a host every second and colours a dot in your menu bar. Glance up, and you know.

A native macOS menu bar app, written in Swift and SwiftUI.

## Features

- <img src="docs/icons/dot-green.png" height="13" alt="" /> **A dot that changes colour** — green, yellow, red. That's the whole interface, most days.
- <img src="docs/icons/ring-green-red.png" height="13" alt="" /> **Recovery rings** — a green dot wearing a red ring means it just came back. Blinks you missed still leave a trace.
- 📈 **Latency sparkline** in the popover and the history window.
- 📜 **History** with status filters, ⌘C on selected rows, and CSV export.
- 🎨 **Your thresholds, your colours.**
- 🚀 **Launch at login** — asked once on first run, and a checkbox in Settings after that.

## Install

Two ways. Both end with PingMate in `/Applications`.

### 📦 Option 1 — Download the DMG

**1.** Download `PingMate-<version>.dmg` from the [**latest release**](https://github.com/kikudjira/pingmate/releases/latest).

**2.** Open it and drag **PingMate** into **Applications**.

**3.** Clear the quarantine flag — one command, once:

```sh
xattr -dr com.apple.quarantine /Applications/PingMate.app
```

**4.** Launch it. The dot appears in the menu bar; there is no Dock icon and no window.

> **Why step 3?** The app isn't signed with a paid Apple certificate, so macOS quarantines the download and says *"PingMate can't be opened because Apple cannot check it for malicious software."* The command above removes the flag. If you'd rather not use a terminal: try to open the app, then go to **System Settings → Privacy & Security** and hit **Open Anyway**.

### 🍺 Option 2 — Homebrew

```sh
brew install --cask kikudjira/pingmate/pingmate
```

That's the whole thing — the tap is added for you and the quarantine flag is cleared automatically. Upgrades later:

```sh
brew upgrade --cask pingmate
```

> **Use the full name.** With the short `brew install --cask pingmate`, Homebrew refuses to load a cask from a tap you haven't trusted and you'd need `brew trust kikudjira/pingmate` first.

## Using it

**Left-click** the dot: latency, sparkline, stats, and buttons for History, Clear and Settings.
**Right-click**: Open History (⌘M), Settings (⌘,), Start/Stop Monitoring, Quit (⌘Q).

| Dot | Meaning | Default |
|-----|---------|---------|
| <img src="docs/icons/dot-green.png" height="12" alt="" /> Green | Good | reply in ≤ 50 ms |
| <img src="docs/icons/dot-yellow.png" height="12" alt="" /> Yellow | Unstable | reply in ≤ 250 ms |
| <img src="docs/icons/dot-red.png" height="12" alt="" /> Red | Problem | slower than that, or no reply |
| ⚪️ White | Paused | not monitoring |

And the rings, which show for five seconds after things improve:

| Ring | Came back from |
|------|----------------|
| <img src="docs/icons/ring-green-yellow.png" height="12" alt="" /> Green in yellow | unstable → good |
| <img src="docs/icons/ring-green-red.png" height="12" alt="" /> Green in red | problem → good |
| <img src="docs/icons/ring-yellow-red.png" height="12" alt="" /> Yellow in red | problem → unstable |

<p align="center">
  <img src="docs/screenshots/history.png" width="560" alt="History window with filters and sparkline" />
</p>

### Settings

<p align="center">
  <img src="docs/screenshots/settings.png" width="400" alt="Settings window" />
</p>

| Setting | Default | Range |
|---------|---------|-------|
| Target | `8.8.8.8` | IPv4, hostname, or `localhost` |
| Interval | 1 s | 0.5–60 s |
| Good threshold | 50 ms | 1–1000 ms |
| Unstable threshold | 250 ms | 1–5000 ms, above the good one |
| History retention | 3 hours | 1 / 3 / 12 / 24 hours |
| Colours | 🟢 `#559C24` 🟡 `#EAA93B` 🔴 `#AE3B36` | anything you like |

## Build from source

```sh
git clone https://github.com/kikudjira/pingmate.git
cd pingmate
./scripts/build-app.sh 1.0.0
open build/Build/Products/Release/PingMate.app
```

Or open `PingMate/PingMate.xcodeproj` and press ⌘R. Needs **macOS 26** and **Xcode 26** — the interface is built on Liquid Glass.

`./scripts/make-dmg.sh 1.0.0` packages it into `dist/`.

## License

[MIT](LICENSE) — Andrey Sekirkin.
