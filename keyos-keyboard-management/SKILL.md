---
name: keyos-keyboard-management
description: Build and review KeyOS or Passport Prime app screens with text fields, on-screen keyboard behavior, focus handling, keyboard avoidance, tap-outside dismissal, modal text entry, Done key behavior, or small-screen form layout.
metadata:
  short-description: KeyOS keyboard and form behavior
---

# KeyOS Keyboard Management

Use this skill when implementing or reviewing KeyOS/Passport Prime app UI that contains editable text, forms, modals, popovers, search boxes, file pickers, dropdowns, PIN screens, or bottom action bars.

## Core Rule

Treat the keyboard as a dynamic viewport obstruction, not as a separate afterthought. Every text entry interaction must preserve the user's ability to see the active field, complete the edit, and return to the previous visual context.

## Required Behavior

- Text fields must visually show focus with the app's active accent treatment, such as a teal border and matching cursor where the UI toolkit allows it.
- The keyboard must open only for text-entry controls. Toggles, dropdowns, filters, icon buttons, record rows, and switches must not trigger keyboard avoidance.
- Tapping anywhere that is not another text-entry control should dismiss the keyboard. This includes filters, menus, rows, empty page areas, modal chrome, buttons, dropdowns, and back/cancel controls.
- Tapping a different text-entry control should move focus to that control and keep the keyboard open.
- The keyboard Done key should complete editing for single-line fields. It must not insert a newline.
- Multi-line fields must have an explicit way to dismiss the keyboard. If Done inserts a newline by toolkit default, add a separate blur/dismiss path or configure the field so Done commits.
- If the active field would be obscured by the keyboard, scroll or translate just enough to keep the field and its cursor visible above the keyboard.
- If the active field is already visible above the keyboard, do not move the view.
- Keyboard avoidance should animate smoothly with the keyboard when possible.
- When the keyboard closes, restore the pre-edit scroll position unless the user manually scrolled during the edit. Do not strand the user at the top or bottom of a form.
- Add temporary bottom scroll inset equal to the keyboard overlap plus a small margin while editing. Remove that inset when the keyboard closes.
- Do not add permanent bottom padding large enough to let the page scroll almost entirely out of view.
- Avoid hardcoded focus hacks such as `viewport-y = -180px`, fixed blank spacers, or "scroll to top on focus". They may pass one field in one simulator state and fail every other text field.

## Forms With Bottom Action Bars

- A bottom action bar with Save, Cancel, Delete, or Continue buttons counts as an obstruction.
- Content must be scrollable far enough that the final editable field can sit above both the keyboard and the bottom action bar.
- Use a bottom fade only when content is actually clipped by fixed controls. Remove the fade when the user is already at the bottom and nothing is hidden.
- Back and Cancel must remain functional while the keyboard is open; they should dismiss or leave the screen according to the current app flow.

## Modals And Popups

- For modal text entry, move the whole modal above the keyboard. Do not scale or shrink the modal unless every internal row is designed to reflow.
- Keep modal buttons inside the modal bounds when the keyboard opens.
- If the modal cannot fit above the keyboard, make the modal body scrollable and keep the action buttons visible.
- Opening a non-text modal or dropdown while a keyboard is open should first dismiss the keyboard, then present the modal/dropdown.

## Implementation Pattern

Use a single focus/keyboard coordinator per screen:

1. Track the focused text control id and its local rectangle.
2. Record the scroll position when the user first enters text-editing mode.
3. Track the keyboard top edge or keyboard height.
4. Compute the visible bottom as `screen_height - keyboard_height - fixed_bottom_bar_height - margin`.
5. If `focused_rect.bottom > visible_bottom`, scroll by the difference plus margin.
6. If `focused_rect.top < header_bottom`, scroll back only enough to reveal the top.
7. Ignore focus/avoidance events from non-text controls.
8. On keyboard dismissal, clear focus and restore the recorded scroll position unless the user has manually scrolled.

Prefer measured rectangles over hardcoded guesses. If the SDK does not expose keyboard geometry directly, centralize the current workaround and add simulator verification notes beside it.

## Regression Tests

Before considering a form screen ready, test these cases in the simulator:

- Tap the top text field: keyboard opens and no unnecessary scroll occurs.
- Tap the last text field: field and cursor remain visible above the keyboard.
- Tap outside the field on empty page space: keyboard closes.
- Tap a dropdown/filter/menu while a field is focused: keyboard closes and the chosen control opens above it.
- Tap a toggle while editing: no keyboard-avoidance scroll fires.
- Press Done on a single-line field: editing exits and no newline is inserted.
- Press Done or the app's dismissal affordance on a multi-line field: the keyboard can be closed.
- Open a text-entry modal: modal moves above the keyboard without scaling and buttons stay inside it.
- Close the keyboard: the screen returns to the previous scroll position.
- Navigate away and back: form screens start at their expected top position unless the app intentionally restores context.

## Common Failure Modes

- Scrolling to the top whenever the keyboard opens means the logic is using a generic focus event rather than the focused text field rectangle.
- A field remains hidden under the keyboard when it is near the bottom of a scroll area because there is no temporary bottom inset.
- A modal's buttons escape the card because the modal is being scaled instead of translated or scrolled.
- Toggles cause the screen to center on themselves because keyboard avoidance is attached to all focused or tapped controls, not just text fields.
- Dropdowns or filter sheets appear behind the keyboard because tap-outside dismissal was not run before opening non-text overlays.
- The screen returns to a confusing position because the original scroll offset was not recorded or because every focus event overwrote it.
