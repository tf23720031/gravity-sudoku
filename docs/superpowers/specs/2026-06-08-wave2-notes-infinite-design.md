# Wave 2: 筆記模式 + 無限模式 Design

## Goal

Add two player-experience features: pencil/notes mode (candidate number annotations) and infinite mode (no heart deductions), both surfaced without modifying the domain puzzle model.

---

## 1. Pencil/Notes Mode

### Activation: Dual-Zone NumberPanel

`NumberPanel` is extended with a second row of smaller buttons below the existing fill row:

- **Upper row (fill zone):** existing large buttons, tap → `onSymbolSelected(sym)` → `SelectSymbol`
- **Lower row (notes zone):** same symbols at ~11sp, tap → `onNoteSelected(sym)` → `SelectNoteSymbol`

The active zone gets a subtle bottom-line or tint highlight. Tapping any upper-row button implicitly exits pencil mode; tapping any lower-row button implicitly enters it.

New `NumberPanel` params:
```dart
final bool isPencilMode;
final ValueChanged<String> onNoteSelected;
```

### State

`GameState` gains:
```dart
final Map<Position, Set<int>> notes;  // default const {}
final bool isPencilMode;              // default false
```

### Events

```dart
class SelectNoteSymbol extends GameEvent {
  final String sym;
  const SelectNoteSymbol(this.sym);
}

class ToggleNote extends GameEvent {
  final int row;
  final int col;
  const ToggleNote(this.row, this.col);
}
```

`SelectSymbol` (existing) is modified to also set `isPencilMode = false`.

### Bloc Logic

**`_onSelectNoteSymbol`:**
```dart
emit(state.copyWith(selectedSymbol: event.sym, isPencilMode: true));
```

**`_onToggleNote`:**
- If `state.selectedSymbol == null`: ignore
- If `cell.isFixed || cell.value != 0`: ignore
- `value = SymbolSystem.toValue(state.selectedSymbol!)`
- Toggle: if present in notes → remove; else → add
- emit `copyWith(notes: newNotes)`

**`_onSelectSymbol` (modify):** add `isPencilMode: false` to existing emit.

### Auto-Clear on Correct Placement

After a correct placement at `(row, col, value)` in `_onPlaceNumber`. First make a mutable copy of notes, then mutate and emit:

```dart
final notes = Map<Position, Set<int>>.from(
  state.notes.map((k, v) => MapEntry(k, Set<int>.from(v))),
);
// Remove all marks from the placed cell
notes.remove(Position(row, col));
// Remove this value from every cell in the same row
for (var c = 0; c < size; c++) notes[Position(row, c)]?.remove(value);
// Remove this value from every cell in the same column
for (var r = 0; r < size; r++) notes[Position(r, col)]?.remove(value);
// Remove this value from the same box
final boxRows = size == 9 ? 3 : (size == 6 ? 2 : 2);
final boxCols = size == 9 ? 3 : (size == 6 ? 3 : 2);
final startRow = (row ~/ boxRows) * boxRows;
final startCol = (col ~/ boxCols) * boxCols;
for (var r = startRow; r < startRow + boxRows; r++) {
  for (var c = startCol; c < startCol + boxCols; c++) {
    notes[Position(r, c)]?.remove(value);
  }
}
```

### Cell Tap Routing

In `game_screen.dart`, `onCellTap` reads current mode from bloc and dispatches the appropriate event:

```dart
onCellTap: (row, col) {
  final bloc = context.read<GameBloc>();
  if (bloc.state.isPencilMode) {
    bloc.add(ToggleNote(row, col));
  } else {
    bloc.add(PlaceNumber(row, col));
  }
},
```

### CellTile Pencil Marks Rendering

`CellTile` gains `notes: Set<int>` (default `const {}`).

Shown when `cell.value == 0 && !cell.isFixed && notes.isNotEmpty`.

Layout: fixed-position mini-grid inside the cell. Each candidate number occupies a predetermined slot:

| Size | Layout |
|------|--------|
| 9×9  | 3 rows × 3 cols (slots 1–9) |
| 6×6  | 2 rows × 3 cols (slots 1–6) |
| 4×4  | 2 rows × 2 cols (slots 1–4) |

Each slot renders the digit in ~10sp grey if present in `notes`, or an empty `SizedBox` otherwise. The grid fills the cell interior using `FractionallySizedBox` or `Padding`.

Pencil marks are only visible when the cell has no value — once a digit is placed the cell's standard rendering takes over and notes are cleared by the auto-clear logic.

### Undo Behavior

Notes are part of `GameState` and therefore part of undo snapshots. However, `isPencilMode` is a UI mode, not a game action, so it should not be restored by undo:

```dart
// In _onUndo:
emit(snapshot.copyWith(isPencilMode: state.isPencilMode));
```

---

## 2. Infinite Mode

### Activation

`DifficultySelectScreen` is converted from `StatelessWidget` to `StatefulWidget`. A `SwitchListTile` is added below the difficulty list:

```
[ 無限模式  ○────── ]
不扣愛心，適合練習
```

Local state: `bool _infiniteMode = false`.

When a difficulty card is tapped, `_infiniteMode` is passed through the navigation chain:

```dart
GameScreen(puzzle: puzzle, puzzleRepo: puzzleRepo, isInfiniteMode: _infiniteMode)
```

### State

`GameBloc` gains a constructor parameter `bool isInfiniteMode = false`, stored as `GameState.isInfiniteMode`. The value is set at construction time and never changes mid-game.

```dart
final bool isInfiniteMode;  // default false
```

`GameScreen` passes `isInfiniteMode` to `GameBloc` in the `BlocProvider.create` callback.

### Bloc Logic Change in `_onPlaceNumber`

```dart
if (isCorrect) {
  // existing correct-placement logic + auto-clear notes
} else {
  if (!state.isInfiniteMode) {
    // existing heart-deduction logic
  }
  // clear selectedSymbol regardless
}
```

### UI Impact

`HeartRow` is hidden when `isInfiniteMode == true`:

```dart
if (puzzle.difficulty != Difficulty.tutorial && !state.isInfiniteMode)
  HeartRow(hearts: state.hearts),
```

---

## Files Changed

| File | Change |
|------|--------|
| `lib/presentation/bloc/game/game_state.dart` | + `notes`, `isPencilMode`, `isInfiniteMode`; copyWith updates |
| `lib/presentation/bloc/game/game_event.dart` | + `SelectNoteSymbol`, `ToggleNote` |
| `lib/presentation/bloc/game/game_bloc.dart` | Modify `_onSelectSymbol`, `_onPlaceNumber`, `_onUndo`; add `_onSelectNoteSymbol`, `_onToggleNote` |
| `lib/presentation/widgets/number_panel.dart` | Dual-zone layout; + `isPencilMode`, `onNoteSelected` |
| `lib/presentation/widgets/cell_tile.dart` | + `notes` param; mini-grid pencil mark rendering |
| `lib/presentation/widgets/sudoku_grid.dart` | Pass `notes` map; per-cell `notes[pos]` lookup |
| `lib/presentation/screens/game/game_screen.dart` | Cell tap routing; pass `isPencilMode` to NumberPanel; HeartRow condition; pass `isInfiniteMode` to GameBloc |
| `lib/presentation/screens/difficulty_select/difficulty_select_screen.dart` | Convert to StatefulWidget; add `_infiniteMode` toggle; pass to GameScreen |

---

## Out of Scope

- Persisting notes across sessions
- Notes for fixed cells or ice blocks
- Visual indication of conflicting notes (marks that contradict placed values)
- Infinite mode mid-game toggle (set once at game start only)
