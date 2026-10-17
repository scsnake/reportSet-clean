# C hospital RIS report send/save toggle DOM

Verified against the IE report page on 2026-07-29:

```text
/webcvis/MJB/MJB3A002.do?index=...&pageid=MJB3A002&reportformid=129
```

The `儲存時發送` button controls whether saving the report also sends it. This
state belongs to the current study page and must be checked again after every
study/page change.

## State mapping

| Report behavior | `sendSelect.value` | Main icon | Meaning |
|---|---:|---|---|
| Save only | `"0"` | `error_16_16.gif` (red cross) | Saving does not send the report |
| Send on save | `"1"` | `check_16_16.gif` (green check) | Saving also sends the report |

Use the live `value` property of `#sendSelect` as the source of truth. The icon
is useful as a visual/secondary verification.

## Relevant elements

### Toggle button

```html
<button
  onclick="sendSelectChange();"
  id="sendSelectButton"
  title="儲存時發送"
  class="defaultButton"
  name="sendSelectButton">
  ...
</button>
```

Clicking this button calls `sendSelectChange()` and toggles the hidden state
between `"0"` and `"1"`. It does not itself save or send the report.

The following properties remain the same in both states and therefore must not
be used to determine the mode:

- `title="儲存時發送"`
- `class="defaultButton"`
- `onclick="sendSelectChange();"`

### Hidden state input

Save-only state:

```html
<input id="sendSelect" type="hidden" value="0" name="sendSelect">
```

Send-on-save state:

```html
<input id="sendSelect" type="hidden" value="1" name="sendSelect">
```

Read the current property:

```javascript
document.getElementById("sendSelect").value
```

Do not use `defaultValue`. During live testing, the page initially loaded with
`value="0"`; after toggling to `"1"`, `defaultValue` remained `"0"`.

### State icon

Save-only:

```html
<img
  id="sendSelectButtonImage"
  name="sendSelectButtonImage"
  src="../images/icon/16x16/error_16_16.gif">
```

Send-on-save:

```html
<img
  id="sendSelectButtonImage"
  name="sendSelectButtonImage"
  src="../images/icon/16x16/check_16_16.gif">
```

The button also contains a second, unchanged help icon:

```html
<img src="../images/icon/16x16/question_fromlib_16_16.gif">
```

Always select the state icon by `id="sendSelectButtonImage"` rather than using
the first/second image position.

## Safe per-study toggle sequence

1. Wait for the new report document to finish loading.
2. Re-acquire `sendSelectButton`, `sendSelect`, and
   `sendSelectButtonImage` from the new document.
3. Read `sendSelect.value`.
4. Click `sendSelectButton` only when the current value differs from the
   desired value.
5. Read `sendSelect.value` again and verify it now matches.
6. Optionally confirm the corresponding icon filename.

Do not retain DOM element references across study navigation. IE replaces the
report document, so references from the previous study can be stale even when
the browser window and its `HWND` are unchanged.

## AutoHotkey v1 example

```ahk
button := wb.document.getElementById("sendSelectButton")
state  := wb.document.getElementById("sendSelect")
icon   := wb.document.getElementById("sendSelectButtonImage")

desiredValue := (sendReportMode = "save") ? "0" : "1"
currentValue := Trim("" state.value)

if (currentValue != desiredValue)
    button.Click()

actualValue := Trim("" state.value)
if (actualValue != desiredValue)
    throw Exception("RIS send/save toggle verification failed")
```

The repository configuration uses:

```ini
[Settings]
sendReportMode=normal
```

- `normal` requests `sendSelect.value = "1"` (green check).
- `save` requests `sendSelect.value = "0"` (red cross).
- A missing file, missing setting, or unsupported value defaults to `normal`.

The current implementation is in `Lib/CH_RIS.ahk`, in
`load_send_report_mode()` and `apply_send_report_mode()`.
