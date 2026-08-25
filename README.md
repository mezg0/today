# Today

A personal menubar todo app for macOS. Tiny feature surface, obsessive polish.

Requires macOS 26 (the panel is Liquid Glass).

## Setup (30 seconds)

1. Open `Today.xcodeproj`.
2. Select the **Today** target → *Signing & Capabilities* → pick your team.
   (One-time. This is what lights up iCloud sync; without a team the app
   still runs, just local-only.)
3. ⌘R.

The app lives in the menubar (no Dock icon). The whole UI is one floating
panel; the menubar icon just has Open and Quit.

## Using it

| | Keys |
| --- | --- |
| Anywhere | **⌥Space** opens/closes the panel. |
| Field | Type + **Enter** adds to the current tab (All = no space). **Esc** clears, then closes. |
| Tabs | **⌘1** All · **⌘2–9** spaces · **⇥ / ⇧⇥** cycle · **+** creates; right-click to rename/delete. |
| List | **↓** from the field enters it · **j/k** or arrows move · **Space** completes · **↩** edits inline · **⌫** deletes · **↑** past the top, or any letter, returns to the field. Right-click a row for Edit / Delete. |

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
