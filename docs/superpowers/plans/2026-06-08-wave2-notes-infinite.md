# Wave 2: Notes Mode + Infinite Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pencil/notes mode (candidate mark annotations per cell) and infinite mode (no heart deductions), both wired through the existing BLoC architecture without modifying domain puzzle models.

**Architecture:** Notes are stored as `Map<Position, Set<int>>` in `GameState` (same tier as `conflicts`, `hintCell`). Infinite mode is a `bool` constructor parameter on `GameBloc`, stored in `GameState.isInfiniteMode` and set once at game start. The NumberPanel gains a second row of smaller pencil-mark buttons; routing at the cell-tap level (game_screen) decides whether to dispatch `PlaceNumber` or `ToggleNote`.

**Tech Stack:** Flutter, flutter_bloc, equatable, bloc_test. All sizes supported (4, 9, 12, 16; 32 skips pencil marks due to cell size).

---

## File Map

| File | Change |
|------|--------|
| `lib/presentation/bloc/game/game_state.dart` | + `notes`, `isPencilMode`, `isInfiniteMode`; update copyWith + props |
| `lib/presentation/bloc/game/game_event.dart` | + `SelectNoteSymbol`, `ToggleNote` |
| `lib/presentation/bloc/game/game_bloc.dart` | + `isInfiniteMode` ctor param; update `_onSelectSymbol`, `_onPlaceNumber`, `_onRestart`; add `_onSelectNoteSymbol`, `_onToggleNote` |
| `lib/presentation/widgets/number_panel.dart` | Add lower pencil row; + `isPencilMode`, `onNoteSelected` |
| `lib/presentation/widgets/cell_tile.dart` | + `notes: Set<int>` param; render mini-grid |
| `lib/presentation/widgets/sudoku_grid.dart` | + `notes` param; pass per-cell slice to CellTile |
| `lib/presentation/screens/game/game_screen.dart` | + `isInfiniteMode` param; cell-tap routing; pass new params through; HeartRow condition |
| `lib/presentation/screens/difficulty_select/difficulty_select_screen.dart` | Convert to StatefulWidget; add `_infiniteMode` toggle |
| `test/presentation/bloc/game_bloc_test.dart` | Update `_makeBloc`; add note + infinite mode tests |

---

### Task 1: GameState — notes, isPencilMode, isInfiniteMode

**Files:**
- Modify: `lib/presentation/bloc/game/game_state.dart`
- Test: `test/presentation/bloc/game_bloc_test.dart`

- [ ] **Step 1: Write failing test**

Add to the `group('GameBloc', ...)` block in `test/presentation/bloc/game_bloc_test.dart`:

```dart
test('GameState initial has empty notes, isPencilMode=false, isInfiniteMode=false', () {
  final state = GameState.initial(Board.empty(4), isTutorial: false);
  expect(state.notes, isEmpty);
  expect(state.isPencilMode, isFalse);
  expect(state.isInfiniteMode, isFalse);
});
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/presentation/bloc/game_bloc_test.dart
```

Expected: compile error — `notes`, `isPencilMode`, `isInfiniteMode` do not exist on `GameState`.

- [ ] **Step 3: Add fields to GameState**

In `lib/presentation/bloc/game/game_state.dart`, after the `permanentlyUnlocked` field (line 26):

```dart
  final Map<Position, Set<int>> notes;
  final bool isPencilMode;
  final bool isInfiniteMode;
```

- [ ] **Step 4: Update constructor**

In the constructor body (after `this.permanentlyUnlocked = const []`):

```dart
    this.notes = const {},
    this.isPencilMode = false,
    this.isInfiniteMode = false,
```

- [ ] **Step 5: Update copyWith signature**

In `copyWith`, after `List<Position>? permanentlyUnlocked`:

```dart
    Map<Position, Set<int>>? notes,
    bool? isPencilMode,
    bool? isInfiniteMode,
```

- [ ] **Step 6: Update copyWith body**

After `permanentlyUnlocked: permanentlyUnlocked ?? this.permanentlyUnlocked,`:

```dart
        notes: notes ?? this.notes,
        isPencilMode: isPencilMode ?? this.isPencilMode,
        isInfiniteMode: isInfiniteMode ?? this.isInfiniteMode,
```

- [ ] **Step 7: Update props**

Replace the `props` getter:

```dart
  @override
  List<Object?> get props => [
        board, initialBoard, selectedSymbol, undoStack, hintCell,
        status, moveCount, elapsedSeconds, hintUsedCount, conflicts,
        lastGravityResult, hearts, undosRemaining, wrongFlashCell,
        lastPlacedCell, lastPlacedValue, unlockedIceBlocks, permanentlyUnlocked,
        notes, isPencilMode, isInfiniteMode,
      ];
```

- [ ] **Step 8: Run test to verify it passes**

```
flutter test test/presentation/bloc/game_bloc_test.dart
```

Expected: all existing tests pass + new test passes.

- [ ] **Step 9: Commit**

```
git add lib/presentation/bloc/game/game_state.dart test/presentation/bloc/game_bloc_test.dart
git commit -m "feat: add notes, isPencilMode, isInfiniteMode to GameState"
```

---

### Task 2: GameEvent — SelectNoteSymbol and ToggleNote

**Files:**
- Modify: `lib/presentation/bloc/game/game_event.dart`

- [ ] **Step 1: Add the two new event classes**

Append to `lib/presentation/bloc/game/game_event.dart`:

```dart
class SelectNoteSymbol extends GameEvent {
  final String sym;
  const SelectNoteSymbol(this.sym);
  @override List<Object?> get props => [sym];
}

class ToggleNote extends GameEvent {
  final int row;
  final int col;
  const ToggleNote(this.row, this.col);
  @override List<Object?> get props => [row, col];
}
```

- [ ] **Step 2: Verify project compiles**

```
flutter analyze lib/presentation/bloc/game/game_event.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add lib/presentation/bloc/game/game_event.dart
git commit -m "feat: add SelectNoteSymbol and ToggleNote events"
```

---

### Task 3: GameBloc — infinite mode

**Files:**
- Modify: `lib/presentation/bloc/game/game_bloc.dart`
- Modify: `lib/presentation/bloc/game/game_state.dart` (GameState.initial)
- Modify: `test/presentation/bloc/game_bloc_test.dart`

**Context:** `GameState.isInfiniteMode` is set once at game start via `GameBloc` constructor. When a wrong answer is placed in non-tutorial mode, the current code deducts a heart. With infinite mode on, this deduction is skipped — the symbol is cleared and the handler returns early without placing the number.

- [ ] **Step 1: Write failing tests**

Add `Cell` import to `test/presentation/bloc/game_bloc_test.dart` (after the existing Board import):

```dart
import 'package:gravity_sudoku/domain/models/cell.dart';
```

Update `_makeBloc` to accept optional parameters (replace the existing `_makeBloc` function):

```dart
GameBloc _makeBloc(
  Board board, {
  Difficulty difficulty = Difficulty.tutorial,
  Board? solution,
  bool isInfiniteMode = false,
}) =>
    GameBloc(
      puzzle: Puzzle(
        id: 0,
        size: board.size,
        difficulty: difficulty,
        initialBoard: board,
        solution: solution ?? board,
      ),
      gravity: GravityEngine(),
      validator: SudokuValidator(),
      hint: HintService(gravity: GravityEngine(), validator: SudokuValidator()),
      audio: _FakeAudio(),
      isInfiniteMode: isInfiniteMode,
    );
```

Add these tests inside the `group('GameBloc', ...)`:

```dart
test('isInfiniteMode=true is stored in initial state', () {
  final bloc = _makeBloc(
    Board.empty(4),
    difficulty: Difficulty.easy,
    isInfiniteMode: true,
  );
  expect(bloc.state.isInfiniteMode, isTrue);
  bloc.close();
});

blocTest<GameBloc, GameState>(
  'PlaceNumber does not deduct hearts when isInfiniteMode=true and answer is wrong',
  build: () {
    // solution has value 2 at (3,0); placing '1' is wrong
    final solution = Board(
      size: 4,
      cells: [
        [Cell(value: 2), Cell(value: 1), Cell(value: 4), Cell(value: 3)],
        [Cell(value: 4), Cell(value: 3), Cell(value: 2), Cell(value: 1)],
        [Cell(value: 3), Cell(value: 4), Cell(value: 1), Cell(value: 2)],
        [Cell(value: 2), Cell(value: 1), Cell(value: 3), Cell(value: 4)],
      ],
    );
    return _makeBloc(
      Board.empty(4),
      difficulty: Difficulty.easy,
      solution: solution,
      isInfiniteMode: true,
    );
  },
  act: (bloc) => bloc
    ..add(const SelectSymbol('1'))
    ..add(const PlaceNumber(0, 0)), // falls to (3,0); solution there is 2 → wrong
  verify: (bloc) {
    expect(bloc.state.hearts, 3); // no deduction
    expect(bloc.state.status, GameStatus.playing);
  },
);
```

- [ ] **Step 2: Run tests to verify they fail**

```
flutter test test/presentation/bloc/game_bloc_test.dart
```

Expected: compile error — `GameBloc` has no `isInfiniteMode` parameter yet.

- [ ] **Step 3: Update GameState.initial to accept isInfiniteMode**

In `lib/presentation/bloc/game/game_state.dart`, replace the factory:

```dart
  factory GameState.initial(Board board,
          {required bool isTutorial, bool isInfiniteMode = false}) =>
      GameState(
        board: board,
        initialBoard: board,
        hearts: 3,
        undosRemaining: isTutorial ? 99 : 1,
        isInfiniteMode: isInfiniteMode,
      );
```

- [ ] **Step 4: Update GameBloc constructor to accept isInfiniteMode**

In `lib/presentation/bloc/game/game_bloc.dart`, update the constructor:

```dart
  GameBloc({
    required Puzzle puzzle,
    required GravityEngine gravity,
    required SudokuValidator validator,
    required HintService hint,
    required AudioService audio,
    bool isInfiniteMode = false,
  })  : _puzzle = puzzle,
        _gravity = gravity,
        _validator = validator,
        _hint = hint,
        _audio = audio,
        super(GameState.initial(
          puzzle.initialBoard,
          isTutorial: puzzle.difficulty == Difficulty.tutorial,
          isInfiniteMode: isInfiniteMode,
        )) {
```

(Register the new event handlers — add these two lines after `on<IceBlockAnimationComplete>(_onIceBlockAnimationComplete);`:)

```dart
    on<SelectNoteSymbol>(_onSelectNoteSymbol);
    on<ToggleNote>(_onToggleNote);
```

- [ ] **Step 5: Modify _onPlaceNumber for infinite mode**

Replace the wrong-answer block in `_onPlaceNumber` (currently lines 84–97):

```dart
    if (!isCorrect && _puzzle.difficulty != Difficulty.tutorial) {
      _audio.playError();
      if (!state.isInfiniteMode) {
        final newHearts = state.hearts - 1;
        _wrongFlashTimer?.cancel();
        emit(state.copyWith(
          hearts: newHearts,
          wrongFlashCell: Position(result.toRow, event.col),
          status: newHearts <= 0 ? GameStatus.gameOver : GameStatus.playing,
        ));
        _wrongFlashTimer = Timer(const Duration(milliseconds: 600), () {
          if (!isClosed) add(const WrongFlashCleared());
        });
      } else {
        emit(state.copyWith(clearSymbol: true));
      }
      return;
    }
```

- [ ] **Step 6: Update _onRestart to preserve isInfiniteMode**

Replace `_onRestart`:

```dart
  void _onRestart(RestartPuzzle event, Emitter<GameState> emit) {
    _wrongFlashTimer?.cancel();
    emit(GameState.initial(
      state.initialBoard,
      isTutorial: _puzzle.difficulty == Difficulty.tutorial,
      isInfiniteMode: state.isInfiniteMode,
    ));
  }
```

- [ ] **Step 7: Add stub handlers (to compile)**

Add at the bottom of `game_bloc.dart` (before `close()`):

```dart
  void _onSelectNoteSymbol(SelectNoteSymbol event, Emitter<GameState> emit) {}

  void _onToggleNote(ToggleNote event, Emitter<GameState> emit) {}
```

- [ ] **Step 8: Run tests to verify they pass**

```
flutter test test/presentation/bloc/game_bloc_test.dart
```

Expected: all tests pass including the 2 new infinite mode tests.

Also run:
```
flutter test test/presentation/bloc/game_bloc_hearts_test.dart
```

Expected: all existing hearts tests still pass (GameBloc constructor is backwards-compatible).

- [ ] **Step 9: Commit**

```
git add lib/presentation/bloc/game/game_state.dart lib/presentation/bloc/game/game_bloc.dart test/presentation/bloc/game_bloc_test.dart
git commit -m "feat: add infinite mode to GameBloc — no heart deduction on wrong answer"
```

---

### Task 4: GameBloc — notes handlers and auto-clear

**Files:**
- Modify: `lib/presentation/bloc/game/game_bloc.dart`
- Modify: `test/presentation/bloc/game_bloc_test.dart`

**Context:** `_onSelectNoteSymbol` sets `isPencilMode=true`. `_onSelectSymbol` now also clears `isPencilMode`. `_onToggleNote` adds/removes a candidate value. `_onPlaceNumber` (correct path) auto-clears conflicting notes in same row, column, and box using `BoardSize.subRows`/`subCols`. Notes persist through undo (not stored in the Board-only undo stack). Need to import `board_sizes.dart`.

- [ ] **Step 1: Write failing tests**

Add these tests to `test/presentation/bloc/game_bloc_test.dart` inside `group('GameBloc', ...)`:

```dart
blocTest<GameBloc, GameState>(
  'SelectNoteSymbol sets isPencilMode=true and selectedSymbol',
  build: () => _makeBloc(Board.empty(4)),
  act: (bloc) => bloc.add(const SelectNoteSymbol('3')),
  verify: (bloc) {
    expect(bloc.state.isPencilMode, isTrue);
    expect(bloc.state.selectedSymbol, '3');
  },
);

blocTest<GameBloc, GameState>(
  'SelectSymbol resets isPencilMode to false',
  build: () => _makeBloc(Board.empty(4)),
  act: (bloc) => bloc
    ..add(const SelectNoteSymbol('3'))
    ..add(const SelectSymbol('2')),
  verify: (bloc) {
    expect(bloc.state.isPencilMode, isFalse);
    expect(bloc.state.selectedSymbol, '2');
  },
);

blocTest<GameBloc, GameState>(
  'ToggleNote adds note value to an empty cell',
  build: () => _makeBloc(Board.empty(4)),
  act: (bloc) => bloc
    ..add(const SelectNoteSymbol('2'))
    ..add(const ToggleNote(0, 1)),
  verify: (bloc) {
    expect(bloc.state.notes[const Position(0, 1)], contains(2));
  },
);

blocTest<GameBloc, GameState>(
  'ToggleNote removes note when already present',
  build: () => _makeBloc(Board.empty(4)),
  act: (bloc) => bloc
    ..add(const SelectNoteSymbol('2'))
    ..add(const ToggleNote(0, 1))
    ..add(const ToggleNote(0, 1)),
  verify: (bloc) {
    final n = bloc.state.notes[const Position(0, 1)];
    expect(n == null || !n.contains(2), isTrue);
  },
);

blocTest<GameBloc, GameState>(
  'ToggleNote does nothing when selectedSymbol is null',
  build: () => _makeBloc(Board.empty(4)),
  act: (bloc) => bloc.add(const ToggleNote(0, 1)),
  verify: (bloc) => expect(bloc.state.notes.isEmpty, isTrue),
);

blocTest<GameBloc, GameState>(
  'ToggleNote does nothing when cell already has a value',
  build: () => _makeBloc(Board.empty(4)),
  act: (bloc) => bloc
    ..add(const SelectSymbol('1'))
    ..add(const PlaceNumber(0, 0))   // lands at (3,0) value=1
    ..add(const SelectNoteSymbol('2'))
    ..add(const ToggleNote(3, 0)),   // cell at (3,0) has value
  verify: (bloc) {
    final n = bloc.state.notes[const Position(3, 0)];
    expect(n == null || !n.contains(2), isTrue);
  },
);

blocTest<GameBloc, GameState>(
  'ToggleNote does nothing when cell is fixed',
  build: () => _makeBloc(Board(
    size: 4,
    cells: [
      [Cell(), Cell(), Cell(), Cell()],
      [Cell(), Cell(), Cell(), Cell()],
      [Cell(), Cell(), Cell(), Cell()],
      [Cell(value: 1, isFixed: true), Cell(), Cell(), Cell()],
    ],
  )),
  act: (bloc) => bloc
    ..add(const SelectNoteSymbol('2'))
    ..add(const ToggleNote(3, 0)),
  verify: (bloc) {
    final n = bloc.state.notes[const Position(3, 0)];
    expect(n == null || !n.contains(2), isTrue);
  },
);

blocTest<GameBloc, GameState>(
  'PlaceNumber auto-clears conflicting notes in same row and column',
  build: () => _makeBloc(Board.empty(4)),
  act: (bloc) => bloc
    ..add(const SelectNoteSymbol('1'))
    ..add(const ToggleNote(3, 1))  // same row as landing position
    ..add(const ToggleNote(2, 0))  // same column as placement column
    ..add(const SelectSymbol('1'))
    ..add(const PlaceNumber(0, 0)), // gravity: falls to (3,0)
  verify: (bloc) {
    final n31 = bloc.state.notes[const Position(3, 1)];
    final n20 = bloc.state.notes[const Position(2, 0)];
    expect(n31 == null || !n31.contains(1), isTrue);
    expect(n20 == null || !n20.contains(1), isTrue);
  },
);
```

- [ ] **Step 2: Run tests to verify they fail**

```
flutter test test/presentation/bloc/game_bloc_test.dart
```

Expected: tests that use `SelectNoteSymbol`/`ToggleNote` fail because handlers are stubs.

- [ ] **Step 3: Add board_sizes import to game_bloc.dart**

At the top of `lib/presentation/bloc/game/game_bloc.dart`, add after the existing imports:

```dart
import '../../../core/constants/board_sizes.dart';
```

- [ ] **Step 4: Implement _onSelectNoteSymbol**

Replace the stub in `game_bloc.dart`:

```dart
  void _onSelectNoteSymbol(SelectNoteSymbol event, Emitter<GameState> emit) {
    _audio.playClick();
    emit(state.copyWith(
        selectedSymbol: event.sym, isPencilMode: true, clearHint: true));
  }
```

- [ ] **Step 5: Update _onSelectSymbol to clear pencil mode**

Replace `_onSelectSymbol`:

```dart
  void _onSelectSymbol(SelectSymbol event, Emitter<GameState> emit) {
    if (event.symbol == state.selectedSymbol && !state.isPencilMode) {
      emit(state.copyWith(clearSymbol: true, clearHint: true, isPencilMode: false));
    } else {
      _audio.playClick();
      emit(state.copyWith(
          selectedSymbol: event.symbol, clearHint: true, isPencilMode: false));
    }
  }
```

- [ ] **Step 6: Implement _onToggleNote**

Replace the stub:

```dart
  void _onToggleNote(ToggleNote event, Emitter<GameState> emit) {
    if (state.selectedSymbol == null) return;
    final cell = state.board.cellAt(event.row, event.col);
    if (cell.isFixed || cell.hasNumber) return;

    final value = SymbolSystem.toValue(state.selectedSymbol!);
    final pos = Position(event.row, event.col);

    final newNotes = Map<Position, Set<int>>.from(
      state.notes.map((k, v) => MapEntry(k, Set<int>.from(v))),
    );
    final cellNotes = newNotes.putIfAbsent(pos, () => {});
    if (cellNotes.contains(value)) {
      cellNotes.remove(value);
      if (cellNotes.isEmpty) newNotes.remove(pos);
    } else {
      cellNotes.add(value);
    }

    emit(state.copyWith(notes: newNotes));
  }
```

- [ ] **Step 7: Add auto-clear notes to _onPlaceNumber (correct path)**

In `_onPlaceNumber`, after `final newUnlocks = _detectNewIceUnlocks(newBoard);` and before the `if (isComplete)` block, insert:

```dart
    // Auto-clear notes: copy, remove placed cell, strip matching value from row/col/box
    final placedRow = result.toRow;
    final placedCol = event.col;
    final bSize = BoardSize.fromInt(state.board.size);
    final newNotes = Map<Position, Set<int>>.from(
      state.notes.map((k, v) => MapEntry(k, Set<int>.from(v))),
    );
    newNotes.remove(Position(placedRow, placedCol));
    for (var c = 0; c < state.board.size; c++) {
      newNotes[Position(placedRow, c)]?.remove(value);
    }
    for (var r = 0; r < state.board.size; r++) {
      newNotes[Position(r, placedCol)]?.remove(value);
    }
    final startRow = (placedRow ~/ bSize.subRows) * bSize.subRows;
    final startCol = (placedCol ~/ bSize.subCols) * bSize.subCols;
    for (var r = startRow; r < startRow + bSize.subRows; r++) {
      for (var c = startCol; c < startCol + bSize.subCols; c++) {
        newNotes[Position(r, c)]?.remove(value);
      }
    }
    newNotes.removeWhere((_, v) => v.isEmpty);
```

Then add `notes: newNotes` to the final `emit(state.copyWith(...))` call:

```dart
    emit(state.copyWith(
      board: newBoard,
      undoStack: newStack.length > 50
          ? newStack.sublist(newStack.length - 50)
          : newStack,
      conflicts: conflicts,
      lastGravityResult: result,
      moveCount: state.moveCount + 1,
      status: isComplete ? GameStatus.completed : GameStatus.playing,
      clearHint: true,
      clearSymbol: symbolExhausted,
      lastPlacedCell: Position(result.toRow, event.col),
      lastPlacedValue: value,
      unlockedIceBlocks: mergedUnlocking,
      notes: newNotes,
    ));
```

- [ ] **Step 8: Run tests to verify they pass**

```
flutter test test/presentation/bloc/game_bloc_test.dart
flutter test test/presentation/bloc/game_bloc_hearts_test.dart
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```
git add lib/presentation/bloc/game/game_bloc.dart test/presentation/bloc/game_bloc_test.dart
git commit -m "feat: add notes handlers and auto-clear to GameBloc"
```

---

### Task 5: NumberPanel — dual-zone UI

**Files:**
- Modify: `lib/presentation/widgets/number_panel.dart`

**Context:** The current `NumberPanel` is a single `Wrap` of 44×54px buttons. We add a second `Wrap` of smaller (36×44px) buttons below it. Both share the same symbol list. The upper row calls `onSymbolSelected`; the lower row calls `onNoteSelected`. A thin divider and a row label (`A` / pencil icon) separates the two zones. The active zone is indicated by a 2px colored bottom border on each button. Since `isPencilMode` never causes a full rebuild of NumberPanel (it's passed as a prop), the BlocBuilder in game_screen handles that.

- [ ] **Step 1: Update NumberPanel signature**

Replace the class definition and constructor in `lib/presentation/widgets/number_panel.dart`:

```dart
class NumberPanel extends StatelessWidget {
  final int boardSize;
  final String? selectedSymbol;
  final Map<String, int> remainingCounts;
  final bool isPencilMode;
  final void Function(String) onSymbolSelected;
  final void Function(String) onNoteSelected;

  const NumberPanel({
    super.key,
    required this.boardSize,
    required this.selectedSymbol,
    required this.remainingCounts,
    required this.isPencilMode,
    required this.onSymbolSelected,
    required this.onNoteSelected,
  });
```

- [ ] **Step 2: Replace build method**

Replace the `build` method:

```dart
  @override
  Widget build(BuildContext context) {
    final symbols = SymbolSystem.forSize(boardSize);

    Widget fillButton(String sym) {
      final remaining = remainingCounts[sym] ?? boardSize;
      final isSelected = sym == selectedSymbol && !isPencilMode;
      final isDone = remaining <= 0;
      return GestureDetector(
        onTap: isDone ? null : () => onSymbolSelected(sym),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 54,
          decoration: BoxDecoration(
            color: isDone
                ? Colors.grey.withValues(alpha: 0.15)
                : isSelected
                    ? AppColors.primary
                    : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: !isPencilMode && isSelected
                ? null
                : Border(
                    bottom: BorderSide(
                      color: !isPencilMode
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
            boxShadow: isDone
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Opacity(
            opacity: isDone ? 0.4 : 1.0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sym,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDone ? '✓' : '×$remaining',
                  style: TextStyle(
                    fontSize: isSelected ? 11 : 10,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isDone
                        ? AppColors.textSecondary
                        : isSelected
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget noteButton(String sym) {
      final remaining = remainingCounts[sym] ?? boardSize;
      final isSelected = sym == selectedSymbol && isPencilMode;
      final isDone = remaining <= 0;
      return GestureDetector(
        onTap: isDone ? null : () => onNoteSelected(sym),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 44,
          decoration: BoxDecoration(
            color: isDone
                ? Colors.grey.withValues(alpha: 0.1)
                : isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              bottom: BorderSide(
                color: isPencilMode
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Opacity(
            opacity: isDone ? 0.3 : 1.0,
            child: Center(
              child: Text(
                sym,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: symbols.map(fillButton).toList(),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: symbols.map(noteButton).toList(),
        ),
      ],
    );
  }
```

- [ ] **Step 3: Verify file compiles**

```
flutter analyze lib/presentation/widgets/number_panel.dart
```

Expected: no errors (the caller in game_screen.dart will have errors until Task 8).

- [ ] **Step 4: Commit**

```
git add lib/presentation/widgets/number_panel.dart
git commit -m "feat: add dual-zone pencil notes row to NumberPanel"
```

---

### Task 6: CellTile — pencil mark mini-grid

**Files:**
- Modify: `lib/presentation/widgets/cell_tile.dart`

**Context:** Add `notes: Set<int>` parameter (default `const {}`). When the cell has no value and notes is non-empty, render a mini fixed-grid inside the cell. The grid has `boardSize.subCols` columns and `boardSize.subRows` rows. Slot for value `v` (1-indexed): row = `(v-1) ~/ subCols`, col = `(v-1) % subCols`. Values > 16 or board size 32 are skipped entirely (cells too small). The mini-grid is rendered inside the `AnimatedContainer` when `!cell.hasNumber`. The `CellTile` doesn't know `boardSize` — it receives the already-computed grid layout params. Add `int gridCols` and `int gridRows` params (both default to 0, which means skip notes).

- [ ] **Step 1: Add notes, gridCols, gridRows params to CellTile**

In `lib/presentation/widgets/cell_tile.dart`, update the `CellTile` widget class:

```dart
class CellTile extends StatefulWidget {
  final Cell cell;
  final bool isConflict;
  final bool isHint;
  final bool isSelected;
  final bool isWrongFlash;
  final bool isNewlyPlaced;
  final bool isUnlocking;
  final bool isPermanentlyUnlocked;
  final Set<int> notes;
  final int gridCols;
  final int gridRows;
  final VoidCallback onTap;
  final VoidCallback? onUnlockComplete;

  const CellTile({
    super.key,
    required this.cell,
    required this.onTap,
    this.isConflict = false,
    this.isHint = false,
    this.isSelected = false,
    this.isWrongFlash = false,
    this.isNewlyPlaced = false,
    this.isUnlocking = false,
    this.isPermanentlyUnlocked = false,
    this.notes = const {},
    this.gridCols = 0,
    this.gridRows = 0,
    this.onUnlockComplete,
  });
```

- [ ] **Step 2: Add _buildNotes helper method to _CellTileState**

Add this method before `build` in `_CellTileState`:

```dart
  Widget _buildNotes() {
    if (widget.gridCols == 0 || widget.gridRows == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.gridRows, (rowIdx) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.gridCols, (colIdx) {
              final v = rowIdx * widget.gridCols + colIdx + 1;
              final show = widget.notes.contains(v);
              return Expanded(
                child: Center(
                  child: show
                      ? Text(
                          SymbolSystem.fromValue(v),
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                            height: 1.1,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
```

- [ ] **Step 3: Update build to show notes when cell is empty**

In `_CellTileState.build`, replace the `AnimatedContainer`'s `child` logic:

```dart
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: widget.cell.hasNumber
                ? Text(
                    SymbolSystem.fromValue(widget.cell.value!),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.cell.isFixed
                          ? AppColors.fixedNumber
                          : AppColors.playerNumber,
                    ),
                  )
                : widget.notes.isNotEmpty
                    ? _buildNotes()
                    : null,
          ),
```

- [ ] **Step 4: Verify file compiles**

```
flutter analyze lib/presentation/widgets/cell_tile.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```
git add lib/presentation/widgets/cell_tile.dart
git commit -m "feat: add pencil mark mini-grid rendering to CellTile"
```

---

### Task 7: SudokuGrid — notes passthrough

**Files:**
- Modify: `lib/presentation/widgets/sudoku_grid.dart`

**Context:** Add `notes: Map<Position, Set<int>>` and `boardSizeEnum: BoardSize?` to `SudokuGrid`. For each cell at `(row, col)`, look up `notes[Position(row, col)]` and pass it to `CellTile`. Also compute and pass `gridCols`/`gridRows` from `BoardSize`. Skip notes for size 32 (`boardSize.n > 16 → gridCols=0, gridRows=0`).

- [ ] **Step 1: Add notes param to SudokuGrid**

In `lib/presentation/widgets/sudoku_grid.dart`, update the class:

```dart
class SudokuGrid extends StatelessWidget {
  final Board board;
  final List<(int, int)> conflicts;
  final Position? hintCell;
  final Position? selectedCell;
  final Position? wrongFlashCell;
  final Position? lastPlacedCell;
  final int? lastPlacedValue;
  final GravityResult? lastGravityResult;
  final List<Position> unlockedIceBlocks;
  final List<Position> permanentlyUnlocked;
  final Map<Position, Set<int>> notes;
  final void Function(int row, int col) onCellTap;
  final VoidCallback? onFallingComplete;
  final void Function(int row, int col)? onIceUnlockComplete;

  const SudokuGrid({
    super.key,
    required this.board,
    required this.onCellTap,
    this.conflicts = const [],
    this.hintCell,
    this.selectedCell,
    this.wrongFlashCell,
    this.lastPlacedCell,
    this.lastPlacedValue,
    this.lastGravityResult,
    this.unlockedIceBlocks = const [],
    this.permanentlyUnlocked = const [],
    this.notes = const {},
    this.onFallingComplete,
    this.onIceUnlockComplete,
  });
```

- [ ] **Step 2: Compute gridCols/gridRows and pass to CellTile**

In `build`, after `final conflictSet = ...`, add:

```dart
    final bSize = BoardSize.fromInt(board.size);
    final gridCols = bSize.n <= 16 ? bSize.subCols : 0;
    final gridRows = bSize.n <= 16 ? bSize.subRows : 0;
```

In the `itemBuilder`, update the `CellTile` call to include notes:

```dart
            return CellTile(
              cell: cell,
              isConflict: conflictSet.contains(key),
              isHint: hintCell?.row == row && hintCell?.col == col,
              isSelected: selectedCell?.row == row && selectedCell?.col == col,
              isWrongFlash:
                  wrongFlashCell?.row == row && wrongFlashCell?.col == col,
              isNewlyPlaced:
                  lastPlacedCell?.row == row && lastPlacedCell?.col == col,
              isUnlocking: unlockedIceBlocks.contains(pos),
              isPermanentlyUnlocked: permanentlyUnlocked.contains(pos),
              notes: notes[pos] ?? const {},
              gridCols: gridCols,
              gridRows: gridRows,
              onTap: () => onCellTap(row, col),
              onUnlockComplete: () => onIceUnlockComplete?.call(row, col),
            );
```

- [ ] **Step 3: Verify file compiles**

```
flutter analyze lib/presentation/widgets/sudoku_grid.dart
```

Expected: no errors (SudokuGrid callers in game_screen will have errors until Task 8).

- [ ] **Step 4: Commit**

```
git add lib/presentation/widgets/sudoku_grid.dart
git commit -m "feat: pass notes and grid layout params through SudokuGrid to CellTile"
```

---

### Task 8: game_screen.dart — wire everything

**Files:**
- Modify: `lib/presentation/screens/game/game_screen.dart`

**Context:** `GameScreen` gains `isInfiniteMode: bool` param and passes it to `GameBloc`. The `onCellTap` callback reads `bloc.state.isPencilMode` to route to `ToggleNote` vs `PlaceNumber`. The SudokuGrid `BlocBuilder` now also watches `notes`. The NumberPanel `BlocBuilder` now also watches `isPencilMode` and calls both `onSymbolSelected` and `onNoteSelected`. HeartRow is hidden when `state.isInfiniteMode`. Also: `GameOverScreen` navigation adds `isInfiniteMode: false`.

- [ ] **Step 1: Add isInfiniteMode to GameScreen and _GameView**

In `lib/presentation/screens/game/game_screen.dart`, update `GameScreen`:

```dart
class GameScreen extends StatelessWidget {
  final Puzzle puzzle;
  final PuzzleRepository puzzleRepo;
  final bool isInfiniteMode;

  const GameScreen({
    super.key,
    required this.puzzle,
    required this.puzzleRepo,
    this.isInfiniteMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => GameBloc(
        puzzle: puzzle,
        gravity: GravityEngine(),
        validator: SudokuValidator(),
        hint: HintService(gravity: GravityEngine(), validator: SudokuValidator()),
        audio: ctx.read<AudioService>(),
        isInfiniteMode: isInfiniteMode,
      ),
      child: _GameView(puzzle: puzzle, puzzleRepo: puzzleRepo),
    );
  }
}
```

Update `_GameView` to pass through (no change needed — GameBloc already has it via constructor).

- [ ] **Step 2: Update HeartRow condition to hide when isInfiniteMode**

Replace the HeartRow BlocBuilder section (currently the `if (widget.puzzle.difficulty != Difficulty.tutorial) BlocBuilder...HeartRow...` block):

```dart
                  if (widget.puzzle.difficulty != Difficulty.tutorial)
                    BlocBuilder<GameBloc, GameState>(
                      buildWhen: (p, c) => p.hearts != c.hearts,
                      builder: (context, state) => state.isInfiniteMode
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: HeartRow(hearts: state.hearts),
                            ),
                    ),
```

- [ ] **Step 3: Update SudokuGrid BlocBuilder to also watch notes**

Replace the `buildWhen` line in the SudokuGrid BlocBuilder:

```dart
                        buildWhen: (p, c) =>
                            p.board != c.board ||
                            p.conflicts != c.conflicts ||
                            p.hintCell != c.hintCell ||
                            p.wrongFlashCell != c.wrongFlashCell ||
                            p.lastPlacedCell != c.lastPlacedCell ||
                            p.lastGravityResult != c.lastGravityResult ||
                            p.unlockedIceBlocks != c.unlockedIceBlocks ||
                            p.permanentlyUnlocked != c.permanentlyUnlocked ||
                            p.notes != c.notes,
```

Pass `notes` to `SudokuGrid`:

```dart
                          builder: (context, state) => SudokuGrid(
                            board: state.board,
                            conflicts: state.conflicts,
                            hintCell: state.hintCell,
                            wrongFlashCell: state.wrongFlashCell,
                            lastPlacedCell: state.lastPlacedCell,
                            lastPlacedValue: state.lastPlacedValue,
                            lastGravityResult: state.lastGravityResult,
                            unlockedIceBlocks: state.unlockedIceBlocks,
                            permanentlyUnlocked: state.permanentlyUnlocked,
                            notes: state.notes,
                            onCellTap: (row, col) {
                              final bloc = context.read<GameBloc>();
                              if (bloc.state.isPencilMode) {
                                bloc.add(ToggleNote(row, col));
                              } else {
                                bloc.add(PlaceNumber(row, col));
                              }
                            },
                            onFallingComplete: () => context
                                .read<GameBloc>()
                                .add(const ClearFallingAnimation()),
                            onIceUnlockComplete: (row, col) => context
                                .read<GameBloc>()
                                .add(IceBlockAnimationComplete(row, col)),
                          ),
```

- [ ] **Step 4: Update NumberPanel BlocBuilder**

Replace the NumberPanel BlocBuilder:

```dart
                  BlocBuilder<GameBloc, GameState>(
                    buildWhen: (p, c) =>
                        p.selectedSymbol != c.selectedSymbol ||
                        p.board != c.board ||
                        p.isPencilMode != c.isPencilMode,
                    builder: (context, state) => NumberPanel(
                      boardSize: widget.puzzle.size,
                      selectedSymbol: state.selectedSymbol,
                      remainingCounts: _computeRemaining(
                          state.board, widget.puzzle.size),
                      isPencilMode: state.isPencilMode,
                      onSymbolSelected: (sym) =>
                          context.read<GameBloc>().add(SelectSymbol(sym)),
                      onNoteSelected: (sym) =>
                          context.read<GameBloc>().add(SelectNoteSymbol(sym)),
                    ),
                  ),
```

- [ ] **Step 5: Add ToggleNote and SelectNoteSymbol to imports**

In the imports section of `game_screen.dart`, verify `game_event.dart` is already imported. The `ToggleNote` and `SelectNoteSymbol` classes are defined there. No new import needed.

- [ ] **Step 6: Verify the whole file compiles**

```
flutter analyze lib/presentation/screens/game/game_screen.dart
```

Expected: no errors.

- [ ] **Step 7: Run all tests**

```
flutter test
```

Expected: all 48 tests (+ new ones from Task 3 and 4) pass.

- [ ] **Step 8: Commit**

```
git add lib/presentation/screens/game/game_screen.dart
git commit -m "feat: wire notes mode and infinite mode into GameScreen"
```

---

### Task 9: DifficultySelectScreen — infinite mode toggle

**Files:**
- Modify: `lib/presentation/screens/difficulty_select/difficulty_select_screen.dart`
- Modify: `lib/presentation/screens/game_over/game_over_screen.dart`

**Context:** `DifficultySelectScreen` is a `StatelessWidget`. Convert it to `StatefulWidget` to hold `_infiniteMode: bool`. Add a `SwitchListTile` below the difficulty list. Pass `isInfiniteMode` to `GameScreen`. Also update `GameOverScreen._newLevel` to pass `isInfiniteMode: false` (game over can't happen in infinite mode, but ensure it compiles cleanly).

- [ ] **Step 1: Convert DifficultySelectScreen to StatefulWidget**

Replace `lib/presentation/screens/difficulty_select/difficulty_select_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/repositories/puzzle_repository.dart';
import '../game/game_screen.dart';

class DifficultySelectScreen extends StatefulWidget {
  final PuzzleRepository puzzleRepo;

  const DifficultySelectScreen({super.key, required this.puzzleRepo});

  @override
  State<DifficultySelectScreen> createState() => _DifficultySelectScreenState();
}

class _DifficultySelectScreenState extends State<DifficultySelectScreen> {
  static const _items = [
    _DifficultyItem(Difficulty.tutorial, 'Tutorial', '4×4 · Learn the rules', Icons.school_outlined),
    _DifficultyItem(Difficulty.easy,     'Easy',     '4×4 · Relaxed',          Icons.sentiment_very_satisfied),
    _DifficultyItem(Difficulty.normal,   'Normal',   '9×9 · Standard Sudoku',  Icons.sentiment_satisfied),
    _DifficultyItem(Difficulty.hard,     'Hard',     '12×12 · With ice blocks', Icons.sentiment_neutral),
    _DifficultyItem(Difficulty.expert,   'Expert',   '16×16 · Advanced',        Icons.sentiment_dissatisfied),
    _DifficultyItem(Difficulty.extreme,  'Extreme',  '32×32 · For masters',     Icons.whatshot),
  ];

  bool _infiniteMode = false;

  Future<void> _start(BuildContext context, Difficulty difficulty) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final puzzle = await widget.puzzleRepo.fetchRandom(difficulty);
      nav.pop(); // dismiss loading
      if (puzzle == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No puzzles available for this difficulty.')),
        );
        return;
      }
      nav.push(MaterialPageRoute(
        builder: (_) => GameScreen(
          puzzle: puzzle,
          puzzleRepo: widget.puzzleRepo,
          isInfiniteMode: _infiniteMode,
        ),
      ));
    } catch (_) {
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to load puzzle. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Difficulty')),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final item = _items[i];
                return _DifficultyCard(
                  item: item,
                  onTap: () => _start(ctx, item.difficulty),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              title: const Text('無限模式'),
              subtitle: const Text('不扣愛心，適合練習'),
              value: _infiniteMode,
              onChanged: (v) => setState(() => _infiniteMode = v),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final _DifficultyItem item;
  final VoidCallback onTap;

  const _DifficultyCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(item.subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.play_arrow_rounded,
                  color: AppColors.primary, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyItem {
  final Difficulty difficulty;
  final String label;
  final String subtitle;
  final IconData icon;
  const _DifficultyItem(this.difficulty, this.label, this.subtitle, this.icon);
}
```

- [ ] **Step 2: Update GameOverScreen._newLevel to pass isInfiniteMode**

In `lib/presentation/screens/game_over/game_over_screen.dart`, update `_newLevel`:

```dart
  Future<void> _newLevel(BuildContext context) async {
    final newPuzzle = await puzzleRepo.fetchRandom(
      puzzle.difficulty,
      excludeId: puzzle.id,
    );
    if (newPuzzle == null || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          puzzle: newPuzzle,
          puzzleRepo: puzzleRepo,
          isInfiniteMode: false,
        ),
      ),
      (route) => route.isFirst,
    );
  }
```

- [ ] **Step 3: Run all tests**

```
flutter test
```

Expected: all tests pass.

- [ ] **Step 4: Run the app and verify visually**

```
flutter run -d web-server --web-port 3456
```

Open browser at `http://localhost:3456`. Verify:
1. Difficulty screen shows 無限模式 toggle at the bottom
2. Toggling infinite mode and starting a game: HeartRow is hidden
3. In a normal game: lower pencil row appears in NumberPanel
4. Tap a lower-zone number → it becomes active (highlighted)
5. Tap an empty cell → pencil mark appears in cell
6. Tap the same lower-zone number again on same cell → mark disappears
7. Tap an upper-zone number → pencil zone deactivates
8. Place a number in a cell → pencil marks with that value clear from same row/col/box

- [ ] **Step 5: Commit**

```
git add lib/presentation/screens/difficulty_select/difficulty_select_screen.dart lib/presentation/screens/game_over/game_over_screen.dart
git commit -m "feat: add infinite mode toggle to DifficultySelectScreen"
```

---

## Done

All 9 tasks complete. Run the full test suite one final time:

```
flutter test
```

Expected: all tests pass with 0 failures.
