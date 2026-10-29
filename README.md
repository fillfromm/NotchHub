# NotchHub

Turns the MacBook notch into a small tool hub. Hover (or click) the notch and it expands into tabs: music, timer, clipboard history, calculator, Claude Code usage, notes, system stats and your next calendar event. On Macs without a notch (or external displays) it becomes a pill at the top-center of the screen.

Swift + SwiftUI + AppKit, macOS 14+, no third-party dependencies. All code is original; the UX idea is inspired by projects like vorssaint.

## Build and run

Requires Xcode or the Command Line Tools (`xcode-select --install`). No Xcode project needed.

```bash
./build.sh
```

This compiles, assembles `build/NotchHub.app`, signs it ad-hoc and launches it. Other options:

```bash
./build.sh --no-run    # build only
./build.sh --debug     # debug build
open build/NotchHub.app
```

NotchHub has no Dock icon: look for the menu bar icon and the notch itself.

## Menu bar

- Enable / disable modules
- Expand on hover or on click
- Launch at login
- Shortcut to Automation privacy settings
- Quit

## Modules

| Module | What it does |
|---|---|
| Music | Now playing, artwork, play/pause/next/previous for Apple Music via AppleScript; remembers the last track (no private MediaRemote) |
| Timer | Countdown, stopwatch, Pomodoro (25/5, long break every 4); notification + sound on finish |
| Clipboard | Last 30 text items, click to re-copy, pin, delete, clear. Stored locally; items marked concealed by password managers are skipped |
| Calculator | Expression input with live result, history, functions (`sqrt sin cos tan ln log abs`, `pi`, `e`) |
| AI usage | Reads Claude Code logs in `~/.claude/projects`: current 5h window, today, last 7 days. Optional token budget bar. API integration is a placeholder; no keys anywhere |
| Quick notes | One scratchpad note, autosaved |
| System | Battery, CPU, memory, disk; low-battery warning in the collapsed notch |
| Calendar | Next events (EventKit); shows "in 12m" in the collapsed notch when one is imminent |

While collapsed, the highest-priority module with live info (timer > calendar > music > low battery) shows an icon and short text beside the notch.

## Permissions

- **Automation (Music):** macOS asks the first time Music is running while NotchHub polls it. If you click Don't Allow, the Music tab says so and links to System Settings › Privacy & Security › Automation. NotchHub only launches Music when you press play while it is closed.
- **Calendars:** requested only when you press "Allow calendar access" in the Calendar tab.
- **Notifications:** requested when you first start a timer.
- Clipboard, system stats and Claude logs need no permission. No data leaves your Mac.

Data is stored in `~/Library/Application Support/NotchHub/`.

## Adding a module

1. Create a class conforming to `NotchModule` (see `Sources/NotchHub/Core/NotchModule.swift`), usually also an `ObservableObject`. Provide `id`, `title`, `icon` (SF Symbol), `makeView()`, and optionally `compactInfo`.
2. Add an instance in `ModuleRegistry.makeDefaultModules()`.

## Layout

```
Sources/NotchHub/
  main.swift, AppDelegate.swift   entry point, menu bar item
  Core/      module protocol, registry, settings, AppleScript runner, local storage, notifications
  Notch/     geometry (notch detection), shape, panel, controller (hover/click), SwiftUI root view
  Modules/   Music, Timer, Clipboard, Calculator, AIUsage, Notes, System, Calendar
build.sh     builds and launches the .app
```

## Known limitations

- Developed and compiled on macOS 14 / Swift 6.0; the UI has had limited hands-on testing. Expect rough edges in animation and sizing.
- Ad-hoc signed, not notarized. "Launch at login" needs the `.app` build.
- Claude's real quota is not available locally, so the limit bar uses a budget you set.
- Clipboard history is text only.
