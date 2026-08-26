---
target: task detail screen (TaskDetailView.swift)
total_score: 16
p0_count: 2
p1_count: 2
timestamp: 2026-08-26T10-03-17Z
slug: today-panel-taskdetailview-swift
---
Method: dual-agent (A: af7b97a9d89612448 · B: ae90d0440387576fb)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 1 | Panel collapses 428→102pt on →; reads as dismissal. No space/done context. |
| 2 | Match System / Real World | 3 | Title-then-notes is the Things/Reminders model. |
| 3 | User Control and Freedom | 2 | Esc works but is undiscoverable; no ⌘Z on this screen; blank title silently becomes "Untitled". |
| 4 | Consistency and Standards | 1 | Row font 13→15 medium, x shifts 27px left, check ring and notes glyph dropped. |
| 5 | Error Prevention | 2 | Single-line title can't wrap; long titles edit blind. |
| 6 | Recognition Rather Than Recall | 1 | Nothing names the space, section, or done state. |
| 7 | Flexibility and Efficiency | 3 | → / Return-to-notes / Esc is tight. Space-to-complete missing here. |
| 8 | Aesthetic and Minimalist Design | 2 | Minimal but empty: 74–81% of width unused, 46pt dead band under "Notes". |
| 9 | Error Recovery | 1 | Save only on focus change; ⌥Space mid-edit can drop the last keystrokes. |
| 10 | Help and Documentation | 0 | No hint anywhere that → opens a task or Esc returns. |
| **Total** | | **16/40** | **Needs work** |

## Anti-Patterns Verdict
LLM: not slop, underdesigned to anonymity. A 560×102pt slab with two lines of text top-left; nothing says "task". Deterministic scan: detector is HTML/CSS-only; `[]` on Swift is a null result. Measured: placeholder "Notes" contrast 1.78:1 (fails 3:1); title 11.6:1; same task moves from x≈86/13pt (list) to x=59/15pt (detail).

## Overall Impression
The "off" feeling is the panel losing 76% of its height in one frame with nothing that connects the new screen to the row you were on. The screen itself is honest and quiet, but it has no context line, no affordance for editing or returning, and an empty band under the placeholder.

## What's Working
- Title and notes share a leading edge within 1px; the NSTextView inset corrections work.
- Return in the title hands off to notes; TextEditor gives Return-as-newline.
- Esc restores the same selected row every time (restoreKeyboard).

## Priority Issues
- [P0] Panel collapses on →. Fix: keep the detail screen at the list screen's last height (store it from onGeometryChange; `frame(minHeight:alignment: .top)`), notes fill the space. Command: layout.
- [P0] No context line. Fix: 11pt semibold secondary line above the title with the space name (Inbox) and "· Done" when done, same style as list section headers. Command: clarify.
- [P1] Editable title and the way back are invisible. Fix: title at 17 semibold (capture-field register), focus lands on title when notes are empty; one-time "esc" hint top-right. Command: onboard.
- [P1] Notes body `.secondary`, placeholder `.quaternary` (1.78:1). Fix: notes `.primary`, placeholder `.tertiary` to match the capture field. Command: polish.
- [P2] Empty notes reserve a 46pt dead band; overflow has no scroll cue. Fix: fill-height notes with a bottom fade when clipped. Command: harden.
- [P3] Title is single-line. Fix: `axis: .vertical, lineLimit(1...3)`. Command: typeset.

## Persona Red Flags
Alex (power user): Space in detail types a space instead of completing; ⌘Z unwired here; Esc has three meanings across the app.
Jordan (first-timer): will not find →; the collapse reads as "I broke it"; won't know the title is editable.

## Minor Observations
Top 18 / bottom 16 asymmetric. Title→notes gap 4pt vs list row rhythm 8. Double-click on a row should open detail. Notes glyph in rows is 9pt tertiary, nearly invisible. Hard-coded 18/13/5/2.5 repeated across files.

## Questions to Consider
- Why a separate screen rather than the row expanding in place (kept checkmark, kept place, no back affordance)?
- Should the detail screen be the one place "height follows content" is suspended?
- The app's signature is the ring→spring check + sound; the detail screen has no signature. What earns its existence beyond a bigger text box?
