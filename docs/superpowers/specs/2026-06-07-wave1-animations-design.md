# Wave 1 UX Animations Design

## Goal

Add three visual enhancements to the game screen: a progress bar, a cell-fill animation (falling trajectory + bounce), and an ice block unlock animation triggered when its row or column becomes complete.

---

## 1. Progress Bar

**Position:** Between HeartRow and TimerRow in the game screen Column.

**Logic:**
- `totalToFill` = count of cells where `!cell.isFixed && !cell.isIceBlock`
- `filledCount` = count of non-fixed, non-ice cells whose `value != 0`
- Progress = `filledCount / totalToFill` (clamped 0.0–1.0)

**Widget:** `_ProgressBar` (private StatelessWidget in `game_screen.dart`)
- Wrapped in `BlocBuilder` that rebuilds only when `board` changes
- Visual: `AnimatedContainer` with `LinearProgressIndicator` or custom `FractionallySizedBox`
- Color interpolation: green (0%) → amber (50%) → red (100%) — represents remaining work decreasing

**Hidden for tutorial difficulty.**

---

## 2. Cell Fill Animation

Two-layer animation triggered on every correct cell placement.

### Layer A: Falling Trajectory

`FallingNumberOverlay` already exists at `lib/presentation/widgets/falling_number_overlay.dart`. It accepts:
- `result: GravityResult` — start/end row
- `value: int` — the number placed
- `cellSize: double` — for pixel positioning
- `onComplete: VoidCallback` — called when animation ends

**Wiring:**
- `GameState` gains `lastPlacedCell: Position?` — set in `_onPlaceNumber` for every correct placement, cleared by a new `ClearFallingAnimation` event
- `GameState` gains `lastGravityResult: GravityResult?` — already exists, used by overlay
- `GameState` gains `lastPlacedValue: int?` — the value placed (for overlay display)
- In `game_screen.dart` Stack, add a `BlocBuilder` watching `lastPlacedCell` that renders `FallingNumberOverlay` when non-null
- `FallingNumberOverlay.onComplete` dispatches `ClearFallingAnimation()` event
- `GameBloc._onClearFalling` emits `copyWith(clearLastPlaced: true)`

**cellSize calculation:** `MediaQuery` of the grid widget area divided by `puzzle.size`

### Layer B: Bounce on Landing

- `SudokuGrid` receives `lastPlacedCell: Position?` (new param)
- `SudokuGrid` passes `isNewlyPlaced: bool` to each `CellTile` — true only when `row == lastPlacedCell.row && col == lastPlacedCell.col`
- `CellTile` becomes a `StatefulWidget` with `SingleTickerProviderStateMixin`
- When `isNewlyPlaced` transitions false→true, trigger `AnimationController` (400ms, `elasticOut` curve): `ScaleTransition` from 1.4 → 1.0
- `isNewlyPlaced` false→false (same symbol re-selected, not a new placement) does nothing

---

## 3. Ice Block Unlock Animation

### Trigger Condition

After each correct placement in `_onPlaceNumber`, for every ice block on the board:
- Check if **every non-ice, non-fixed cell in that ice block's row** has `value != 0` (i.e., a value placed)
- OR if **every non-ice, non-fixed cell in that ice block's column** has the same condition
- If either is true, the ice block is "unlocked"

### State Changes

- `GameState` gains `unlockedIceBlocks: Set<Position>` (immutable, empty by default)
- `_onPlaceNumber` computes newly unlocked positions and merges into state
- New event `IceBlockAnimationComplete(int row, int col)` — dispatched by CellTile after animation finishes
- `GameBloc._onIceBlockAnimationComplete` removes the position from `unlockedIceBlocks`

### Board Data

The `Board` data model is **not modified** — ice blocks remain `isIceBlock == true` in the Board. The unlock is purely visual: once a position is in `unlockedIceBlocks`, CellTile renders the shatter animation instead of the ice block appearance.

Two sets track lifecycle:
- `unlockedIceBlocks: Set<Position>` — currently playing shatter animation
- `permanentlyUnlocked: Set<Position>` — animation done, render as empty cell

When `IceBlockAnimationComplete` fires, `GameBloc` moves the position from `unlockedIceBlocks` into `permanentlyUnlocked`. `CellTile` renders an empty transparent cell if `isPermanentlyUnlocked: true`, regardless of `cell.isIceBlock`.

### Animation

- `CellTile`: when `isUnlocking: bool` transitions false→true, play `ScaleTransition` (1.0 → 0.0) + `FadeTransition` (1.0 → 0.0), both 300ms `easeIn`
- On animation complete, call `onUnlockComplete()` which dispatches `IceBlockAnimationComplete`
- After removal from `unlockedIceBlocks`, if in `permanentlyUnlocked`, render as empty/transparent cell

---

## Files Changed

| File | Change |
|------|--------|
| `lib/presentation/bloc/game/game_state.dart` | + `lastPlacedCell`, `lastPlacedValue`, `unlockedIceBlocks`, `permanentlyUnlocked`; copyWith flags: `clearLastPlaced`, `clearUnlocked` |
| `lib/presentation/bloc/game/game_event.dart` | + `ClearFallingAnimation`, `IceBlockAnimationComplete(row, col)` |
| `lib/presentation/bloc/game/game_bloc.dart` | `_onPlaceNumber`: set `lastPlacedCell`/`lastPlacedValue`, compute ice unlock; + `_onClearFalling`, `_onIceBlockAnimationComplete` handlers |
| `lib/presentation/widgets/cell_tile.dart` | → StatefulWidget; + `isNewlyPlaced`, `isUnlocking`, `isPermanentlyUnlocked`, `onUnlockComplete` params; bounce + shatter animations |
| `lib/presentation/widgets/sudoku_grid.dart` | + `lastPlacedCell`, `unlockedIceBlocks`, `permanentlyUnlocked` params; pass to CellTile |
| `lib/presentation/screens/game/game_screen.dart` | Add `_ProgressBar`; wire `FallingNumberOverlay` in Stack; update SudokuGrid call |

---

## Out of Scope

- Modifying `Board` or `GravityEngine` data structures
- Persisting unlock state across sessions
- Sound effects for animations (handled by existing audio system already in game_bloc)
- Tutorial difficulty: progress bar hidden; animations still play
