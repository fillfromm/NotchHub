# NotchHub

Turns the MacBook notch into a small tool hub. Hover (or click) the notch and it expands into tabs: music, timer and alarm, clipboard history, volume and your next calendar event. On Macs without a notch (or external displays) it becomes a pill at the top-center of the screen.

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
| Timer & Alarm | Countdown with iPhone-style wheels, stopwatch, alarm clock that shows "rings in 7 h 25 min"; notification + sound |
| Clipboard | Two pages in one window: Text (last 30 items) and Screenshots (copied images, last 20, draggable into other apps). Click to copy. Stored locally; items marked concealed by password managers are skipped |
| Volume | Volume and mute per output device, click a device to switch output (speakers, headphones, monitor), plus the Music app's own volume. Per-app volume for other apps needs a virtual audio driver and is not possible with public macOS APIs |
| Profile | Editable rows: name a row yourself ("Phone", "LinkedIn") and type its value; a button copies it. Stored locally |
| Translate | Word/phrase translation between English, Russian and Czech. Uses the free MyMemory web service, so the typed text is sent to it |
| Windows | Lists open windows and snaps the chosen one to a half, quarter, third or the full screen (Accessibility permission; re-grant after a rebuild) |
| Pictures | Keep a few pictures (a class schedule, a map) and see the selected one large. The notch reopens on the last used tab, so hovering shows it immediately. Add by drag and drop, file picker or clipboard |
| Settings | Everything configurable lives here: tabs on/off, hover/click, tab icons top or side, icon size, zoom, launch at login |
| Calendar | Month grid you can page through (arrows or swipe), dots on days with events or reminders, the selected day's events, and your own reminders with a notification at the chosen time. Shows "in 12m" in the collapsed notch when something is imminent |

While collapsed, the highest-priority module with live info (timer > calendar > music) shows an icon and short text beside the notch.

## Permissions

- **Automation (Music):** macOS asks the first time Music is running while NotchHub polls it. If you click Don't Allow, the Music tab says so and links to System Settings › Privacy & Security › Automation. NotchHub only launches Music when you press play while it is closed.
- **Calendars:** requested only when you press "Show my calendar events" in the Calendar tab. Reminders work without it (stored locally; notifications are requested when you add the first one).
- **Notifications:** requested when you first start a timer.
- Clipboard needs no permission. No data leaves your Mac.

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
  Modules/   Music, Timer, Clipboard, Volume, Calendar, Profile, Translator, Windows, Pictures, Settings
build.sh     builds and launches the .app
```

## Known limitations

- Developed and compiled on macOS 14 / Swift 6.0; the UI has had limited hands-on testing. Expect rough edges in animation and sizing.
- Ad-hoc signed, not notarized. "Launch at login" needs the `.app` build.
- Claude's real quota is not available locally, so the limit bar uses a budget you set.
- Clipboard history is text only.

## Claude Code status line (limit left + reset time)

`scripts/claude-statusline.py` prints the real remaining usage limit and the time until it resets
inside Claude Code itself, using the `rate_limits` data Claude Code passes to status line scripts
(Pro/Max plans). Enable it in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "python3 -I /absolute/path/to/NotchHub/scripts/claude-statusline.py",
    "refreshInterval": 60
  }
}
```

## Privacy

NotchHub stores everything (clipboard history, screenshots, profile rows, pictures, reminders) locally in
`~/Library/Application Support/NotchHub/` and has no analytics or accounts. The only network use is the
Translate tab, which sends the text you type to the free MyMemory service (api.mymemory.translated.net).

## License

[MIT](LICENSE). Use it, change your own copy as you like; changes to this repository go through the owner.
