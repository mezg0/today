# Today

Today is a todo list for macOS that runs as a floating panel. Press `⌥Space` to
open it over the current app, add or work through tasks with the keyboard, and
press `Esc` to close it. It has no main window and no Dock icon; a menubar icon
provides Open, Launch at Login, and Quit.

![The Today panel open over the desktop](docs/screenshot.png)

## Purpose

Today is built for fast task management: getting a thought out of your head
and into a list, or clearing the next thing off it, should take a couple of
seconds and not pull you out of whatever you were doing. Most of the design
follows from that.

- The panel opens with a global hotkey over the current app, with the text
  field already focused, so capturing a task is `⌥Space`, type, `Enter`, `Esc`.
- Everything is reachable from the keyboard, and the mouse is never required.
- The list is limited to what is relevant now: open tasks, today's completed
  ones, and anything snoozed until tomorrow. There are no due dates, tags,
  priorities, or settings.
- Nothing animates apart from the completion checkmark, so the panel keeps up
  with typing.

## Requirements

macOS 26 or later.

## Install

Download `Today-<version>.zip` from the
[Releases page](https://github.com/mezg0/today/releases), unzip it, and move
`Today.app` to your Applications folder. It is signed and notarized, so it
opens without a warning, and it syncs through iCloud.

### Building it yourself

You need Xcode, and an Apple Developer team if you want iCloud sync. Without a
team the app still builds and runs, with data kept on the local Mac only.

1. Open `Today.xcodeproj` in Xcode.
2. Select the Today target, open Signing & Capabilities, and choose your team.
   This enables iCloud sync and only needs doing once.
3. Run with `⌘R`. The app appears in the menubar.

To build from the terminal instead (unsigned, local data only):

```sh
xcodebuild -project Today.xcodeproj -scheme Today -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Debug/Today.app
```

To start it automatically at login, choose Launch at Login from the menubar
icon.

## Using it

### Adding a task

Press `⌥Space`. The text field at the top of the panel is focused. Type the task
and press `Enter`. The task is added to the top of the list, in the space shown
by the current tab. The field clears and stays focused so you can add another.
`Esc` clears the field; a second `Esc` closes the panel.

### Spaces

The tabs under the field are spaces. The first tab, All, shows every task
grouped by space. The others show one space each.

- `⌘1` selects All; `⌘2` to `⌘9` select spaces in tab order. `Tab` and `⇧Tab` cycle.
- `⌘N`, or the `+` pill, creates a space. Type a name and press `Enter`.
- Right-click a space to rename or delete it. Deleting a space does not delete
  its tasks; they become unfiled and appear under Inbox on the All tab.

### The list

The list shows every task that is not done, followed by two optional sections:
Snoozed, and Done (tasks completed today).

- Press `↓` from the field to move into the list, then `↑` and `↓` to move between
  rows. Pressing `↑` on the first row returns to the field, as does typing any
  letter.
- `Space` completes the selected task. The row keeps its place briefly, then
  moves to the Done section. `Space` on a Done task un-completes it.
- `⌘S` snoozes the selected task until midnight. It moves to the Snoozed section.
  `⌘S` on a snoozed task wakes it immediately.
- `⌥↑` and `⌥↓` move the selected task up or down within its space.
- `⌘⌫` deletes the selected task. `⌘Z` undoes the last change.

When every task in the current tab is done or snoozed, the list is replaced by
a single line such as "All clear · 4 done today". Done tasks are kept and
reappear if a task is added or woken.

### Notes on a task

Press `Enter` on a selected row, or double-click it, to open the task. The screen
shows the title, which can be edited, and a notes area below it. Changes save
as you type. `Enter` in the title moves to the notes; `⌘↩` completes or
un-completes the task; `Esc` returns to the list with the same row selected.
Tasks with notes show a small glyph in the list.

## Keys

| Context | Key | Action |
| :-- | :-- | :-- |
| Anywhere | `⌥Space` | Open or close the panel |
| Field | `Enter` | Add the task |
| Field | `↓` | Move into the list |
| Field | `Esc` | Clear the field, or close the panel if empty |
| Tabs | `⌘1` | Show All |
| Tabs | `⌘2` to `⌘9` | Show a space |
| Tabs | `Tab`, `⇧Tab` | Next or previous tab |
| Tabs | `⌘N` | New space |
| List | `↑` `↓` | Move between rows |
| List | `Space` | Complete or un-complete |
| List | `Enter` | Open the task |
| List | `⌘S` | Snooze until tomorrow, or wake |
| List | `⌥↑` `⌥↓` | Move the task within its space |
| List | `⌘⌫` | Delete |
| List | `⌘Z` | Undo |
| List | any letter | Return to the field |
| Task | `Enter` (in the title) | Move to notes |
| Task | `⌘↩` | Complete or un-complete |
| Task | `Esc` | Back to the list |

## Data and sync

Tasks are stored with SwiftData at
`~/Library/Application Support/Today/Today.store`. When the app is signed with
a team, the store is mirrored to the private CloudKit container
`iCloud.com.brandongomes.today`. Unsigned builds detect the missing entitlement
and keep data local. See `Today/Models/Store.swift`.

## Releasing

`scripts/release.sh 0.2.0` archives the app, signs it with Developer ID,
submits it to Apple for notarization, staples the ticket, and attaches the zip
to a GitHub Release tagged `v0.2.0`. Two one-time steps are needed first, both
tied to the Apple account:

1. In Xcode, Settings › Accounts › Manage Certificates, add a Developer ID
   Application certificate.
2. Store a notarization credential:
   `xcrun notarytool store-credentials Today --apple-id <your Apple ID> --team-id 7M3B48C774`,
   using an app-specific password from appleid.apple.com.

Downloads from the Releases page open without a Gatekeeper warning and sync
through iCloud.

## Changing things

- Hotkey: if `⌥Space` is already used on your Mac (some input source switchers
  take it), change the modifier in `Today/App/HotKey.swift`.
- Project file: `Today.xcodeproj` is generated from `project.yml`. After
  editing `project.yml`, run `brew install xcodegen && xcodegen`.
- Sound: the completion sound is produced by `scripts/make_sounds.py`. Edit
  the values, run the script, and rebuild.
