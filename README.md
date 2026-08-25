# Today

A personal menubar todo app for macOS. Tiny feature surface, obsessive polish.

## Setup (30 seconds)

1. Open `Today.xcodeproj`.
2. Select the **Today** target → *Signing & Capabilities* → pick your team.
   (One-time. This is what lights up iCloud sync; without a team the app
   still runs, just local-only.)
3. ⌘R.

The app lives in the menubar (no Dock icon). Quit from the popover footer.

## Using it

| Where | Keys |
| --- | --- |
| Anywhere | **⌥Space** — capture panel. Enter saves, Esc cancels. |
| Capture panel | **⌘2–9** route the task to a space, **⌘1** back to no space. |
| Menubar popover | **j/k** or arrows move · **Space** completes · **⌫** deletes |
| Menubar popover | **1** All · **2–9** spaces · **⇥ / ⇧⇥** cycle |
| Space pills | **+** creates a space; right-click a pill to rename/delete. |

## Notes

- Hotkey collides with an input-source switcher? Change the modifier in
  `Today/App/HotKey.swift` (`HotKeyConfig`).
- Data: SwiftData store at `~/Library/Application Support/Today/Today.store`,
  synced to the private CloudKit container `iCloud.com.brandongomes.today`
  when the build is signed with a team. Unsigned builds fall back to local-only
  automatically (see `Store.swift`).
- Regenerate the Xcode project after editing `project.yml`:
  `brew install xcodegen && xcodegen`.
- Completion sound is synthesised by `scripts/make_sounds.py`.
