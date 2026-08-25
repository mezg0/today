# Today

A small todo app for macOS that lives in the menubar. Press ⌥Space from any
app and a floating panel appears: a text field, a row of tabs for your
"spaces", and the list of what's left today. Everything is done from the
keyboard.

Requires macOS 26, because the panel uses Liquid Glass.

## Setup

1. Open `Today.xcodeproj` in Xcode.
2. Select the Today target, go to Signing & Capabilities, and pick your team.
   You only do this once. With a team, tasks sync through iCloud; without one,
   the app still works but keeps its data on this Mac only.
3. Press ⌘R.

There is no Dock icon. The menubar icon has two items, Open and Quit; the panel
is the whole interface.

If you would rather build from the terminal:

```
xcodebuild -project Today.xcodeproj -scheme Today -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Debug/Today.app
```

That build is unsigned, so it runs without iCloud sync.

## Keys

| Key | What it does |
| --- | --- |
| ⌥Space | Open or close the panel, from anywhere. |
| Enter | Add what you typed to the current tab. On the All tab the task has no space. |
| Esc | Clear the field if it has text, otherwise close the panel. |
| ⌘1 | Show the All tab. |
| ⌘2 to ⌘9 | Show a space. |
| Tab, Shift-Tab | Cycle through tabs. |
| ↓ | Move from the field into the list. |
| j / k or arrows | Move through the list. |
| Space | Complete the selected task. Press again to un-complete. |
| Enter (in the list) | Edit the selected task inline. Enter saves, Esc cancels. |
| ⌫ | Delete the selected task. |
| ⌘Z | Undo. |
| ↑ past the top, or any letter | Back to the field. |

The "+" pill at the end of the tab row creates a space. Right-click a space to
rename or delete it; right-click a task to edit or delete it. Deleting a space
leaves its tasks in place, unfiled.

## Notes

If ⌥Space is already taken on your Mac (some input source switchers use it),
change the modifier in `Today/App/HotKey.swift`.

Data is a SwiftData store at `~/Library/Application Support/Today/Today.store`.
Signed builds mirror it to the private CloudKit container
`iCloud.com.brandongomes.today`; unsigned builds detect the missing entitlement
and stay local. See `Today/Models/Store.swift`.

The Xcode project is generated from `project.yml`. After editing it, run
`brew install xcodegen && xcodegen`.

The completion sound is synthesised by `scripts/make_sounds.py`. Edit the
numbers, run it again, rebuild.
