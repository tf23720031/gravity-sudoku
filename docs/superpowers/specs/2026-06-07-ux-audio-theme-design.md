# UX / Audio / Theme Enhancement — Design Spec

**Date:** 2026-06-07
**Scope:** 6 gameplay experience improvements

---

## 1. Remove Level Title from AppBar

`GameScreen` AppBar `title` removed (or replaced with difficulty name). No level number shown.

---

## 2. Game Over Screen — Navigation

Triggered when `hearts == 0`. Two actions:

| Button | Label | Action |
|--------|-------|--------|
| Primary | 重新開始 | `RestartPuzzle` event on GameBloc; pop dialog + stay on GameScreen |
| Secondary | 換一關 | `puzzleRepo.fetchRandom(difficulty)` → `pushReplacement(GameScreen(newPuzzle))` |

`GameOverScreen` receives `puzzle: Puzzle` and `puzzleRepo: PuzzleRepository` via constructor (passed from `GameScreen` which already has both).

The `/game_over` named route is replaced by a direct `push` from `GameScreen`'s BlocListener so it can pass the objects.

---

## 3. Completion Screen — Navigation

Two actions:

| Button | Label | Action |
|--------|-------|--------|
| Primary | 繼續相同難度 | `puzzleRepo.fetchRandom(difficulty)` → `pushReplacement(GameScreen(newPuzzle))` |
| Secondary | 選難度 | `popUntil(isFirst)` |

`CompletionScreen` receives `stars`, `elapsedSeconds`, `puzzle: Puzzle`, `puzzleRepo: PuzzleRepository`.

The `/completion` named route is replaced by a direct `pushReplacement` from `GameScreen`'s BlocListener.

---

## 4. Long Press to Select / Deselect Number

`NumberPanel` change:
- Each button: `onLongPress` triggers same logic as `onTap` (selects symbol)
- Long press an **already-selected** symbol → deselects (emit `SelectSymbol` with current symbol acts as toggle in `GameBloc`)

`GameBloc.SelectSymbol` updated: if incoming symbol == current `selectedSymbol`, clear it (toggle). This makes both tap and long press share the same toggle logic.

---

## 5. Audio System

### Audio files (generated via Node.js WAV synthesis)

| File | Description |
|------|-------------|
| `assets/audio/click.wav` | Soft sine blip — selecting a number |
| `assets/audio/thud.wav` | Low thud — number landing |
| `assets/audio/error.wav` | Short buzz — wrong placement |
| `assets/audio/complete.wav` | Rising chime — puzzle complete |
| `assets/audio/bg_music.wav` | 4-bar ambient loop — in-game background |

### AudioService (`lib/core/services/audio_service.dart`)

```
AudioService
  playClick()
  playThud()
  playError()
  playComplete()
  startMusic()
  stopMusic()
  setSfxEnabled(bool)
  setMusicEnabled(bool)
```

Uses `audioplayers` `AudioPlayer`. Two players: one for sfx (short sounds), one for looping music.

### Integration

- `GameBloc` receives `AudioService` in constructor
- Calls: `playClick` on `SelectSymbol`, `playThud` on successful placement, `playError` on wrong placement, `playComplete` on completion
- `SettingsBloc` `ToggleSfx` / `ToggleMusic` → calls `audioService.setSfxEnabled` / `setMusicEnabled`
- Music starts when `GameScreen` mounts, stops on dispose

---

## 6. Dark / Light Theme Toggle

### SettingsBloc promotion

`SettingsBloc` moved from non-existent to `BlocProvider` wrapping `MaterialApp` in `main.dart`. `GravitySudokuApp` becomes a `StatelessWidget` that reads `BlocBuilder<SettingsBloc, SettingsState>` to set `themeMode`.

### Toggle locations

**HomeScreen** — `IconButton` in AppBar trailing:
- Light mode → `Icons.dark_mode_outlined`
- Dark mode → `Icons.light_mode_outlined`
- Taps → `SettingsBloc.add(ChangeTheme(isDark ? 'light' : 'dark'))`

**Pause menu** — add a `SwitchListTile` row for theme, same event.

---

## Files Changed Summary

| File | Change |
|------|--------|
| `lib/presentation/screens/game/game_screen.dart` | Remove AppBar title; pass puzzle+repo to GameOver/Completion; start/stop music |
| `lib/presentation/screens/game_over/game_over_screen.dart` | Accept puzzle+repo; add two action buttons |
| `lib/presentation/screens/completion/completion_screen.dart` | Accept puzzle+repo; replace Back button with two actions |
| `lib/presentation/widgets/number_panel.dart` | Add onLongPress (same as onTap) |
| `lib/presentation/bloc/game/game_bloc.dart` | SelectSymbol toggle; inject AudioService; call audio on events |
| `lib/presentation/bloc/game/game_event.dart` | No change (toggle handled in bloc) |
| `lib/presentation/bloc/settings/settings_bloc.dart` | Wire audio service on sfx/music toggle |
| `lib/core/services/audio_service.dart` | New file — audioplayers wrapper |
| `lib/main.dart` | Promote SettingsBloc; pass AudioService to GameBloc via route |
| `lib/presentation/screens/home/home_screen.dart` | Add theme toggle IconButton |
| `tools/generate_audio.js` | New — Node.js WAV synthesizer |
| `assets/audio/*.wav` | Generated audio files |
