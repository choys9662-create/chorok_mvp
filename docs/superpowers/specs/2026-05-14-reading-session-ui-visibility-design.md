# Reading Session UI Visibility — Design Spec

Date: 2026-05-14  
File: `lib/features/home/screen/reading_session_screen.dart`

## Problem

The reading session screen hides its entire UI (including the timer) after 4 seconds of inactivity via `_uiHideTimer`. This causes two issues:

1. **Typing**: When the user focuses the sentence input field, the keyboard opens but no taps register on the screen — so the UI hides after 4 seconds mid-typing.
2. **OCR loading**: While OCR is processing (`_isOcrLoading = true`), there is no fullscreen overlay — only the camera button icon changes to a hourglass. The user has no clear signal that something is happening.

The recording overlay (`_RecordingOverlay`) already exists and is acceptable as-is.

## Scope

Single file change: `reading_session_screen.dart`.

## Design

### 1. Typing — Keep UI Visible While Focused

**State addition in `_ReadingSessionScreenState`:**
```dart
bool _isTyping = false;
```

**`_resetUiTimer()` guard:**
```dart
void _resetUiTimer() {
  setState(() => _isUiVisible = true);
  _uiHideTimer?.cancel();
  if (_isTyping) return; // do not restart timer while keyboard is open
  _uiHideTimer = Timer(const Duration(seconds: 4), () {
    final t = ref.read(timerProvider);
    if (mounted && t.isRunning) {
      setState(() => _isUiVisible = false);
    }
  });
}
```

**`_ChosuActionBar` — add `onFocusChanged` callback and `FocusNode`:**
- New parameter: `final ValueChanged<bool> onFocusChanged`
- `FocusNode _focusNode` created in `_ChosuActionBarState`, disposed in `dispose()`
- Listener added in `initState()`: calls `widget.onFocusChanged(_focusNode.hasFocus)` on change
- `TextField` receives `focusNode: _focusNode`

**Parent wires it up:**
```dart
_BottomArea(
  ...
  onFocusChanged: (focused) {
    setState(() => _isTyping = focused);
    if (focused) {
      _uiHideTimer?.cancel();
      setState(() => _isUiVisible = true);
    } else {
      _resetUiTimer();
    }
  },
)
```

`_BottomArea` passes `onFocusChanged` down to `_ChosuActionBar` (new parameter on both widgets).

**Result:** UI stays visible for the entire duration the keyboard is open. The moment the user dismisses the keyboard, the 4-second auto-hide resumes normally.

---

### 2. OCR Loading Overlay

**New widget `_OcrLoadingOverlay`** added to the file, following the exact pattern of `_RecordingOverlay`:

```
Positioned.fill
└── Container(color: Colors.black.withValues(alpha: 0.6))
    └── Column(mainAxisAlignment: center)
        ├── Icon(Icons.document_scanner_outlined, white, size: 48)
        ├── SizedBox(height: 16)
        ├── CircularProgressIndicator(color: _kGreen, strokeWidth: 2)
        ├── SizedBox(height: 16)
        └── Text('텍스트 인식 중...', white, fontSize: 14)
```

No tap handler (OCR is not cancellable). `IgnorePointer` wraps the overlay so taps pass through to nothing meaningful.

**Shown in `build()`** alongside the existing recording overlay:
```dart
if (_isOcrLoading)
  const _OcrLoadingOverlay(),
if (_isRecording)
  _RecordingOverlay(
    recognizedText: _recognizedText,
    onStop: _toggleRecording,
  ),
```

OCR overlay disappears automatically when `_isOcrLoading` returns to `false` and ChosuSheet opens.

---

## Behavior Summary

| State | Timer visibility |
|---|---|
| Idle (no interaction) | Hides after 4 seconds |
| Screen tapped | Resets to 4 seconds |
| Text field focused (typing) | Always visible, timer paused |
| Text field unfocused | 4-second countdown resumes |
| Recording (`_isRecording`) | `_RecordingOverlay` shown (existing) |
| OCR loading (`_isOcrLoading`) | `_OcrLoadingOverlay` shown (new) |

## Files Changed

- `lib/features/home/screen/reading_session_screen.dart`
  - `_ReadingSessionScreenState`: add `_isTyping`, update `_resetUiTimer()`
  - `_BottomArea`: add `onFocusChanged` param, pass to `_ChosuActionBar`
  - `_ChosuActionBar` / `_ChosuActionBarState`: add `onFocusChanged` param, `FocusNode`
  - New widget: `_OcrLoadingOverlay`
  - `build()`: add `_OcrLoadingOverlay` to Stack layer ④
