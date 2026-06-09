# Wave 1 Animations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a progress bar, falling-number + bounce cell animation, and ice-block unlock animation triggered when a row or column becomes fully filled.

**Architecture:** New GameState fields drive purely-visual animation params that flow through BlocBuilders into SudokuGrid and CellTile. FallingNumberOverlay (already exists) is wired inside SudokuGrid via LayoutBuilder. CellTile becomes a StatefulWidget owning one AnimationController that serves both the bounce (on placement) and the shatter (on ice unlock) depending on which flag becomes true.

**Tech Stack:** Flutter, flutter_bloc, `AnimationController` / `ScaleTransition` / `FadeTransition`, `Curves.elasticOut` (bounce), `Curves.easeIn` (shatter), `LinearProgressIndicator`.

---

## File Map

| File | Change |
|------|--------|
| `lib/presentation/bloc/game/game_state.dart` | + 4 new fields; update `copyWith`, `initial`, `props` |
| `lib/presentation/bloc/game/game_event.dart` | + `ClearFallingAnimation`, `IceBlockAnimationComplete` |
| `lib/presentation/bloc/game/game_bloc.dart` | + 3 new handlers; update `_onPlaceNumber` and `_onUndo`; register events |
| `lib/presentation/widgets/cell_tile.dart` | StatelessWidget → StatefulWidget; bounce + shatter via single AnimationController |
| `lib/presentation/widgets/sudoku_grid.dart` | + 6 new params; LayoutBuilder + Stack for FallingNumberOverlay; pass new params to CellTile |
| `lib/presentation/screens/game/game_screen.dart` | Add `_ProgressBar`; update SudokuGrid BlocBuilder + call |
| `test/presentation/bloc/game_bloc_test.dart` | Fix `_makeBloc` to pass `audio:` (it was missing after AudioService was added) |

---

### Task 1: Extend GameState and GameEvent

**Files:**
- Modify: `lib/presentation/bloc/game/game_state.dart`
- Modify: `lib/presentation/bloc/game/game_event.dart`

- [ ] **Step 1: Replace game_state.dart**

```dart
import 'package:equatable/equatable.dart';
import '../../../core/utils/position.dart';
import '../../../domain/models/board.dart';
import '../../../domain/models/gravity_result.dart';

enum GameStatus { playing, paused, completed, gameOver }

class GameState extends Equatable {
  final Board board;
  final Board initialBoard;
  final String? selectedSymbol;
  final List<Board> undoStack;
  final Position? hintCell;
  final GameStatus status;
  final int moveCount;
  final int elapsedSeconds;
  final int hintUsedCount;
  final List<(int, int)> conflicts;
  final GravityResult? lastGravityResult;
  final int hearts;
  final int undosRemaining;
  final Position? wrongFlashCell;
  final Position? lastPlacedCell;
  final int? lastPlacedValue;
  final List<Position> unlockedIceBlocks;
  final List<Position> permanentlyUnlocked;

  const GameState({
    required this.board,
    required this.initialBoard,
    this.selectedSymbol,
    this.undoStack = const [],
    this.hintCell,
    this.status = GameStatus.playing,
    this.moveCount = 0,
    this.elapsedSeconds = 0,
    this.hintUsedCount = 0,
    this.conflicts = const [],
    this.lastGravityResult,
    this.hearts = 3,
    this.undosRemaining = 1,
    this.wrongFlashCell,
    this.lastPlacedCell,
    this.lastPlacedValue,
    this.unlockedIceBlocks = const [],
    this.permanentlyUnlocked = const [],
  });

  factory GameState.initial(Board board, {required bool isTutorial}) =>
      GameState(
        board: board,
        initialBoard: board,
        hearts: 3,
        undosRemaining: isTutorial ? 99 : 1,
      );

  GameState copyWith({
    Board? board,
    Board? initialBoard,
    String? selectedSymbol,
    List<Board>? undoStack,
    Position? hintCell,
    GameStatus? status,
    int? moveCount,
    int? elapsedSeconds,
    int? hintUsedCount,
    List<(int, int)>? conflicts,
    GravityResult? lastGravityResult,
    int? hearts,
    int? undosRemaining,
    Position? wrongFlashCell,
    Position? lastPlacedCell,
    int? lastPlacedValue,
    List<Position>? unlockedIceBlocks,
    List<Position>? permanentlyUnlocked,
    bool clearHint = false,
    bool clearGravityResult = false,
    bool clearSymbol = false,
    bool clearWrongFlash = false,
    bool clearLastPlaced = false,
  }) =>
      GameState(
        board: board ?? this.board,
        initialBoard: initialBoard ?? this.initialBoard,
        selectedSymbol:
            clearSymbol ? null : (selectedSymbol ?? this.selectedSymbol),
        undoStack: undoStack ?? this.undoStack,
        hintCell: clearHint ? null : (hintCell ?? this.hintCell),
        status: status ?? this.status,
        moveCount: moveCount ?? this.moveCount,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        hintUsedCount: hintUsedCount ?? this.hintUsedCount,
        conflicts: conflicts ?? this.conflicts,
        lastGravityResult: clearGravityResult
            ? null
            : (lastGravityResult ?? this.lastGravityResult),
        hearts: hearts ?? this.hearts,
        undosRemaining: undosRemaining ?? this.undosRemaining,
        wrongFlashCell:
            clearWrongFlash ? null : (wrongFlashCell ?? this.wrongFlashCell),
        lastPlacedCell:
            clearLastPlaced ? null : (lastPlacedCell ?? this.lastPlacedCell),
        lastPlacedValue:
            clearLastPlaced ? null : (lastPlacedValue ?? this.lastPlacedValue),
        unlockedIceBlocks: unlockedIceBlocks ?? this.unlockedIceBlocks,
        permanentlyUnlocked: permanentlyUnlocked ?? this.permanentlyUnlocked,
      );

  int get stars {
    final heartsLost = 3 - hearts;
    if (hintUsedCount == 0 && heartsLost == 0) return 3;
    if (hintUsedCount <= 1 && heartsLost <= 1) return 2;
    return 1;
  }

  @override
  List<Object?> get props => [
        board, initialBoard, selectedSymbol, undoStack, hintCell,
        status, moveCount, elapsedSeconds, hintUsedCount, conflicts,
        lastGravityResult, hearts, undosRemaining, wrongFlashCell,
        lastPlacedCell, lastPlacedValue, unlockedIceBlocks, permanentlyUnlocked,
      ];
}
```

- [ ] **Step 2: Append two new events to game_event.dart**

Add at the end of `lib/presentation/bloc/game/game_event.dart` (after `WrongFlashCleared`):

```dart
class ClearFallingAnimation extends GameEvent {
  const ClearFallingAnimation();
}

class IceBlockAnimationComplete extends GameEvent {
  final int row;
  final int col;
  const IceBlockAnimationComplete(this.row, this.col);
  @override List<Object?> get props => [row, col];
}
```

- [ ] **Step 3: Verify the app still compiles**

Run: `D:\flutter\bin\flutter.bat analyze lib/presentation/bloc/game/`
Expected: no errors (new fields have defaults, existing callers of `copyWith` are still valid)

- [ ] **Step 4: Commit**

```
git add lib/presentation/bloc/game/game_state.dart lib/presentation/bloc/game/game_event.dart
git commit -m "feat: extend GameState and GameEvent for wave1 animations"
```

---

### Task 2: Update GameBloc

**Files:**
- Modify: `lib/presentation/bloc/game/game_bloc.dart`
- Modify: `test/presentation/bloc/game_bloc_test.dart`

- [ ] **Step 1: Fix the broken test helper first**

`_makeBloc` in `test/presentation/bloc/game_bloc_test.dart` was written before `AudioService` was added to `GameBloc`. Add a `_FakeAudio` class and pass it:

```dart
import 'package:gravity_sudoku/core/services/audio_service.dart';

class _FakeAudio extends AudioService {
  @override Future<void> playClick() async {}
  @override Future<void> playThud() async {}
  @override Future<void> playError() async {}
  @override Future<void> playComplete() async {}
  @override Future<void> startMusic() async {}
  @override Future<void> stopMusic() async {}
}

GameBloc _makeBloc(Board board) => GameBloc(
      puzzle: Puzzle(
        id: 0,
        size: board.size,
        difficulty: Difficulty.tutorial,
        initialBoard: board,
        solution: board,
      ),
      gravity: GravityEngine(),
      validator: SudokuValidator(),
      hint: HintService(gravity: GravityEngine(), validator: SudokuValidator()),
      audio: _FakeAudio(),
    );
```

- [ ] **Step 2: Run existing tests to confirm they now compile and pass**

Run: `D:\flutter\bin\flutter.bat test test/presentation/bloc/game_bloc_test.dart -v`
Expected: All tests PASS

- [ ] **Step 3: Add new tests for the new bloc behavior**

Append these test cases inside the existing `group('GameBloc', ...)` in `test/presentation/bloc/game_bloc_test.dart`:

```dart
    blocTest<GameBloc, GameState>(
      'PlaceNumber sets lastPlacedCell and lastPlacedValue on correct move',
      build: () => _makeBloc(emptyBoard),
      act: (bloc) => bloc
        ..add(const SelectSymbol('1'))
        ..add(const PlaceNumber(0, 0)),
      verify: (bloc) {
        // Tutorial mode: every placement is "correct" (solution == initialBoard)
        // Number falls to bottom row (row 3 in a 4x4 board)
        expect(bloc.state.lastPlacedCell, const Position(3, 0));
        expect(bloc.state.lastPlacedValue, 1);
      },
    );

    blocTest<GameBloc, GameState>(
      'ClearFallingAnimation clears lastPlacedCell and lastPlacedValue',
      build: () => _makeBloc(emptyBoard),
      act: (bloc) => bloc
        ..add(const SelectSymbol('1'))
        ..add(const PlaceNumber(0, 0))
        ..add(const ClearFallingAnimation()),
      verify: (bloc) {
        expect(bloc.state.lastPlacedCell, isNull);
        expect(bloc.state.lastPlacedValue, isNull);
      },
    );

    blocTest<GameBloc, GameState>(
      'IceBlockAnimationComplete moves position to permanentlyUnlocked',
      build: () => _makeBloc(emptyBoard),
      seed: () => GameState.initial(emptyBoard, isTutorial: true).copyWith(
        unlockedIceBlocks: const [Position(2, 2)],
      ),
      act: (bloc) => bloc.add(const IceBlockAnimationComplete(2, 2)),
      verify: (bloc) {
        expect(bloc.state.unlockedIceBlocks, isEmpty);
        expect(bloc.state.permanentlyUnlocked, contains(const Position(2, 2)));
      },
    );
```

- [ ] **Step 4: Run new tests to verify they fail (TDD)**

Run: `D:\flutter\bin\flutter.bat test test/presentation/bloc/game_bloc_test.dart -v`
Expected: New tests FAIL with "GameBloc has no handler for ClearFallingAnimation" or similar

- [ ] **Step 5: Update game_bloc.dart**

Full replacement of `lib/presentation/bloc/game/game_bloc.dart`:

```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/symbols.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/utils/position.dart';
import '../../../domain/models/board.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/services/gravity_engine.dart';
import '../../../domain/services/hint_service.dart';
import '../../../domain/services/sudoku_validator.dart';
import 'game_event.dart';
import 'game_state.dart';

class GameBloc extends Bloc<GameEvent, GameState> {
  final Puzzle _puzzle;
  final GravityEngine _gravity;
  final SudokuValidator _validator;
  final HintService _hint;
  final AudioService _audio;
  Timer? _timer;
  Timer? _wrongFlashTimer;

  GameBloc({
    required Puzzle puzzle,
    required GravityEngine gravity,
    required SudokuValidator validator,
    required HintService hint,
    required AudioService audio,
  })  : _puzzle = puzzle,
        _gravity = gravity,
        _validator = validator,
        _hint = hint,
        _audio = audio,
        super(GameState.initial(
          puzzle.initialBoard,
          isTutorial: puzzle.difficulty == Difficulty.tutorial,
        )) {
    on<SelectSymbol>(_onSelectSymbol);
    on<PlaceNumber>(_onPlaceNumber);
    on<UndoMove>(_onUndo);
    on<RestartPuzzle>(_onRestart);
    on<RequestHint>(_onHint);
    on<PauseGame>(_onPause);
    on<ResumeGame>(_onResume);
    on<TimerTicked>(_onTick);
    on<WrongFlashCleared>(_onWrongFlashCleared);
    on<ClearFallingAnimation>(_onClearFalling);
    on<IceBlockAnimationComplete>(_onIceBlockAnimationComplete);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed && state.status == GameStatus.playing) add(const TimerTicked());
    });
  }

  void _onSelectSymbol(SelectSymbol event, Emitter<GameState> emit) {
    if (event.symbol == state.selectedSymbol) {
      emit(state.copyWith(clearSymbol: true, clearHint: true));
    } else {
      _audio.playClick();
      emit(state.copyWith(selectedSymbol: event.symbol, clearHint: true));
    }
  }

  void _onPlaceNumber(PlaceNumber event, Emitter<GameState> emit) {
    if (state.status != GameStatus.playing) return;
    final sym = state.selectedSymbol;
    if (sym == null) return;
    final cell = state.board.cellAt(event.row, event.col);
    if (cell.isIceBlock || cell.isFixed) return;

    final value = SymbolSystem.toValue(sym);
    final result =
        _gravity.simulate(state.board, col: event.col, fromRow: event.row);
    final landCell = state.board.cellAt(result.toRow, event.col);
    if (!landCell.isEmpty) return;

    final solutionValue =
        _puzzle.solution.cellAt(result.toRow, event.col).value;
    final isCorrect = solutionValue == value;

    if (!isCorrect && _puzzle.difficulty != Difficulty.tutorial) {
      _audio.playError();
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
      return;
    }

    final newBoard =
        _gravity.apply(state.board, col: event.col, value: value, result: result);
    final conflicts = _validator.findConflicts(newBoard);
    final newStack = [...state.undoStack, state.board];
    final isComplete = conflicts.isEmpty && _validator.isComplete(newBoard);

    var placedCount = 0;
    for (var r = 0; r < newBoard.size; r++) {
      for (var c = 0; c < newBoard.size; c++) {
        if (newBoard.cellAt(r, c).value == value) placedCount++;
      }
    }
    final symbolExhausted = placedCount >= _puzzle.size;

    final newUnlocks = _detectNewIceUnlocks(newBoard);
    final mergedUnlocking = [...state.unlockedIceBlocks, ...newUnlocks];

    if (isComplete) {
      _audio.playComplete();
    } else {
      _audio.playThud();
    }

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
    ));
  }

  List<Position> _detectNewIceUnlocks(Board board) {
    final newUnlocks = <Position>[];
    for (var r = 0; r < board.size; r++) {
      for (var c = 0; c < board.size; c++) {
        final cell = board.cellAt(r, c);
        if (!cell.isIceBlock) continue;
        final pos = Position(r, c);
        if (state.unlockedIceBlocks.contains(pos)) continue;
        if (state.permanentlyUnlocked.contains(pos)) continue;

        var rowComplete = true;
        for (var cc = 0; cc < board.size; cc++) {
          final rc = board.cellAt(r, cc);
          if (!rc.isIceBlock && rc.isEmpty) {
            rowComplete = false;
            break;
          }
        }

        var colComplete = true;
        for (var rr = 0; rr < board.size; rr++) {
          final rc = board.cellAt(rr, c);
          if (!rc.isIceBlock && rc.isEmpty) {
            colComplete = false;
            break;
          }
        }

        if (rowComplete || colComplete) newUnlocks.add(pos);
      }
    }
    return newUnlocks;
  }

  void _onUndo(UndoMove event, Emitter<GameState> emit) {
    if (state.undoStack.isEmpty) return;
    if (state.undosRemaining <= 0) return;
    final prev = state.undoStack.last;
    final newStack =
        state.undoStack.sublist(0, state.undoStack.length - 1);
    emit(state.copyWith(
      board: prev,
      undoStack: newStack,
      conflicts: _validator.findConflicts(prev),
      undosRemaining: state.undosRemaining - 1,
      clearGravityResult: true,
      clearHint: true,
      clearLastPlaced: true,
    ));
  }

  void _onRestart(RestartPuzzle event, Emitter<GameState> emit) {
    _wrongFlashTimer?.cancel();
    emit(GameState.initial(
      state.initialBoard,
      isTutorial: _puzzle.difficulty == Difficulty.tutorial,
    ));
  }

  void _onHint(RequestHint event, Emitter<GameState> emit) {
    final move =
        _hint.suggest(state.board, boardSize: _puzzle.size);
    if (move == null) return;
    emit(state.copyWith(
      hintCell: Position(move.row, move.col),
      hintUsedCount: state.hintUsedCount + 1,
    ));
  }

  void _onPause(PauseGame event, Emitter<GameState> emit) {
    emit(state.copyWith(status: GameStatus.paused));
  }

  void _onResume(ResumeGame event, Emitter<GameState> emit) {
    emit(state.copyWith(status: GameStatus.playing));
  }

  void _onTick(TimerTicked event, Emitter<GameState> emit) {
    emit(state.copyWith(elapsedSeconds: state.elapsedSeconds + 1));
  }

  void _onWrongFlashCleared(
      WrongFlashCleared event, Emitter<GameState> emit) {
    emit(state.copyWith(clearWrongFlash: true));
  }

  void _onClearFalling(ClearFallingAnimation event, Emitter<GameState> emit) {
    emit(state.copyWith(clearLastPlaced: true));
  }

  void _onIceBlockAnimationComplete(
      IceBlockAnimationComplete event, Emitter<GameState> emit) {
    final pos = Position(event.row, event.col);
    final newUnlocking =
        state.unlockedIceBlocks.where((p) => p != pos).toList();
    final newPermanent = [...state.permanentlyUnlocked, pos];
    emit(state.copyWith(
      unlockedIceBlocks: newUnlocking,
      permanentlyUnlocked: newPermanent,
    ));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _wrongFlashTimer?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 6: Run all bloc tests**

Run: `D:\flutter\bin\flutter.bat test test/presentation/bloc/ -v`
Expected: All tests PASS

- [ ] **Step 7: Commit**

```
git add lib/presentation/bloc/game/game_bloc.dart test/presentation/bloc/game_bloc_test.dart
git commit -m "feat: add wave1 animation handlers to GameBloc; fix missing audio in test helper"
```

---

### Task 3: Convert CellTile to StatefulWidget with bounce + shatter

**Files:**
- Modify: `lib/presentation/widgets/cell_tile.dart`

Background: CellTile currently is a `StatelessWidget`. It needs one `AnimationController` that drives either a bounce (when a number lands: scale 1.4→1.0, elasticOut, 400ms) or a shatter (when ice block unlocks: scale 1.0→0.0 + opacity 1.0→0.0, easeIn, 300ms). A single controller is sufficient because each cell can only animate one thing at a time (regular cells bounce, ice cells shatter — never both).

- [ ] **Step 1: Replace cell_tile.dart**

```dart
import 'package:flutter/material.dart';
import '../../core/constants/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/cell.dart';
import 'ice_block_tile.dart';

class CellTile extends StatefulWidget {
  final Cell cell;
  final bool isConflict;
  final bool isHint;
  final bool isSelected;
  final bool isWrongFlash;
  final bool isNewlyPlaced;
  final bool isUnlocking;
  final bool isPermanentlyUnlocked;
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
    this.onUnlockComplete,
  });

  @override
  State<CellTile> createState() => _CellTileState();
}

class _CellTileState extends State<CellTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Animation<double> _scale = const AlwaysStoppedAnimation(1.0);
  Animation<double> _opacity = const AlwaysStoppedAnimation(1.0);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.isUnlocking) {
        widget.onUnlockComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(CellTile old) {
    super.didUpdateWidget(old);
    if (!old.isNewlyPlaced && widget.isNewlyPlaced) {
      _ctrl.duration = const Duration(milliseconds: 400);
      _scale = Tween<double>(begin: 1.4, end: 1.0)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
      _opacity = const AlwaysStoppedAnimation(1.0);
      _ctrl.forward(from: 0);
    } else if (!old.isUnlocking && widget.isUnlocking) {
      _ctrl.duration = const Duration(milliseconds: 300);
      final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
      _scale = Tween<double>(begin: 1.0, end: 0.0).animate(curved);
      _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(curved);
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPermanentlyUnlocked) {
      return GestureDetector(onTap: widget.onTap, child: const SizedBox.expand());
    }

    if (widget.cell.isIceBlock) {
      return FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: const IceBlockTile(),
        ),
      );
    }

    Color bg = Colors.transparent;
    if (widget.isConflict) bg = AppColors.conflict.withValues(alpha: 0.2);
    if (widget.isHint) bg = AppColors.hint.withValues(alpha: 0.3);
    if (widget.isSelected) bg = AppColors.primary.withValues(alpha: 0.15);
    if (widget.isWrongFlash) bg = Colors.red.withValues(alpha: 0.45);

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
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
              : null,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compile**

Run: `D:\flutter\bin\flutter.bat analyze lib/presentation/widgets/cell_tile.dart`
Expected: no errors

- [ ] **Step 3: Commit**

```
git add lib/presentation/widgets/cell_tile.dart
git commit -m "feat: CellTile bounce on placement + shatter on ice unlock"
```

---

### Task 4: Update SudokuGrid to support FallingNumberOverlay and new CellTile params

**Files:**
- Modify: `lib/presentation/widgets/sudoku_grid.dart`

Background: SudokuGrid needs to pass `isNewlyPlaced`, `isUnlocking`, `isPermanentlyUnlocked`, `onUnlockComplete` to each CellTile, and host FallingNumberOverlay in a LayoutBuilder-wrapped Stack. New params use defaults so existing usages outside game_screen (if any) don't break.

- [ ] **Step 1: Replace sudoku_grid.dart**

```dart
import 'package:flutter/material.dart';
import '../../core/constants/board_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/position.dart';
import '../../domain/models/board.dart';
import '../../domain/models/gravity_result.dart';
import 'cell_tile.dart';
import 'falling_number_overlay.dart';

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
    this.onFallingComplete,
    this.onIceUnlockComplete,
  });

  @override
  Widget build(BuildContext context) {
    final boardSize = BoardSize.fromInt(board.size);
    final conflictSet = conflicts.map((e) => '${e.$1},${e.$2}').toSet();

    final gridWidget = AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _GridPainter(boardSize),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: board.size,
          ),
          itemCount: board.size * board.size,
          itemBuilder: (ctx, idx) {
            final row = idx ~/ board.size;
            final col = idx % board.size;
            final cell = board.cellAt(row, col);
            final key = '$row,$col';
            final pos = Position(row, col);
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
              onTap: () => onCellTap(row, col),
              onUnlockComplete: () => onIceUnlockComplete?.call(row, col),
            );
          },
        ),
      ),
    );

    final withOverlay = LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth / board.size;
        return Stack(
          children: [
            gridWidget,
            if (lastGravityResult != null &&
                lastPlacedValue != null &&
                onFallingComplete != null)
              FallingNumberOverlay(
                key: ValueKey(
                    'fall_${lastGravityResult!.col}_${lastGravityResult!.fromRow}_${lastGravityResult!.toRow}'),
                result: lastGravityResult!,
                value: lastPlacedValue!,
                cellSize: cellSize,
                onComplete: onFallingComplete!,
              ),
          ],
        );
      },
    );

    if (board.size > 16) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: withOverlay,
      );
    }
    return withOverlay;
  }
}

class _GridPainter extends CustomPainter {
  final BoardSize boardSize;
  _GridPainter(this.boardSize);

  @override
  void paint(Canvas canvas, Size size) {
    final n = boardSize.n;
    final cellSize = size.width / n;

    for (var i = 0; i <= n; i++) {
      final isBoldCol = i % boardSize.subCols == 0;
      final colPaint = Paint()
        ..color = isBoldCol ? AppColors.gridLineBold : AppColors.gridLine
        ..strokeWidth = isBoldCol ? 2.0 : 0.5;
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, size.height),
        colPaint,
      );

      final isBoldRow = i % boardSize.subRows == 0;
      final rowPaint = Paint()
        ..color = isBoldRow ? AppColors.gridLineBold : AppColors.gridLine
        ..strokeWidth = isBoldRow ? 2.0 : 0.5;
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(size.width, i * cellSize),
        rowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.boardSize != boardSize;
}
```

- [ ] **Step 2: Verify compile**

Run: `D:\flutter\bin\flutter.bat analyze lib/presentation/widgets/sudoku_grid.dart`
Expected: no errors

- [ ] **Step 3: Commit**

```
git add lib/presentation/widgets/sudoku_grid.dart
git commit -m "feat: SudokuGrid hosts FallingNumberOverlay + passes animation params to CellTile"
```

---

### Task 5: Wire game_screen — progress bar + updated BlocBuilders

**Files:**
- Modify: `lib/presentation/screens/game/game_screen.dart`

Background: Add `_ProgressBar` widget (hidden for tutorial), update the SudokuGrid BlocBuilder to watch new state fields and pass new callbacks, and add the `_ProgressBar` between HeartRow and `_TimerRow`.

- [ ] **Step 1: Replace game_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/symbols.dart';
import '../../../core/services/audio_service.dart';
import '../../../domain/models/board.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/repositories/puzzle_repository.dart';
import '../../../domain/services/gravity_engine.dart';
import '../../../domain/services/hint_service.dart';
import '../../../domain/services/sudoku_validator.dart';
import '../../bloc/game/game_bloc.dart';
import '../../bloc/game/game_event.dart';
import '../../bloc/game/game_state.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../bloc/settings/settings_event.dart';
import '../../bloc/settings/settings_state.dart';
import '../../widgets/game_controls.dart';
import '../../widgets/heart_row.dart';
import '../../widgets/number_panel.dart';
import '../../widgets/sudoku_grid.dart';
import '../../widgets/tutorial_overlay.dart';
import '../completion/completion_screen.dart';
import '../game_over/game_over_screen.dart';

class GameScreen extends StatelessWidget {
  final Puzzle puzzle;
  final PuzzleRepository puzzleRepo;

  const GameScreen({
    super.key,
    required this.puzzle,
    required this.puzzleRepo,
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
      ),
      child: _GameView(puzzle: puzzle, puzzleRepo: puzzleRepo),
    );
  }
}

class _GameView extends StatefulWidget {
  final Puzzle puzzle;
  final PuzzleRepository puzzleRepo;

  const _GameView({required this.puzzle, required this.puzzleRepo});

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> {
  AudioService? _audio;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _audio = context.read<AudioService>();
      _audio?.startMusic();
    }
  }

  @override
  void dispose() {
    _audio?.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameBloc, GameState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == GameStatus.completed) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CompletionScreen(
                stars: state.stars,
                elapsedSeconds: state.elapsedSeconds,
                puzzle: widget.puzzle,
                puzzleRepo: widget.puzzleRepo,
              ),
            ),
          );
        } else if (state.status == GameStatus.gameOver) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GameOverScreen(
                puzzle: widget.puzzle,
                puzzleRepo: widget.puzzleRepo,
                onRestart: () {
                  if (context.mounted) {
                    context.read<GameBloc>().add(const RestartPuzzle());
                  }
                },
              ),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: () => _showPauseMenu(context),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  if (widget.puzzle.difficulty != Difficulty.tutorial)
                    BlocBuilder<GameBloc, GameState>(
                      buildWhen: (p, c) => p.hearts != c.hearts,
                      builder: (context, state) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: HeartRow(hearts: state.hearts),
                      ),
                    ),
                  if (widget.puzzle.difficulty != Difficulty.tutorial)
                    const _ProgressBar(),
                  _TimerRow(),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: BlocBuilder<GameBloc, GameState>(
                        buildWhen: (p, c) =>
                            p.board != c.board ||
                            p.conflicts != c.conflicts ||
                            p.hintCell != c.hintCell ||
                            p.wrongFlashCell != c.wrongFlashCell ||
                            p.lastPlacedCell != c.lastPlacedCell ||
                            p.lastGravityResult != c.lastGravityResult ||
                            p.unlockedIceBlocks != c.unlockedIceBlocks ||
                            p.permanentlyUnlocked != c.permanentlyUnlocked,
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
                          onCellTap: (row, col) {
                            context
                                .read<GameBloc>()
                                .add(PlaceNumber(row, col));
                          },
                          onFallingComplete: () => context
                              .read<GameBloc>()
                              .add(const ClearFallingAnimation()),
                          onIceUnlockComplete: (row, col) => context
                              .read<GameBloc>()
                              .add(IceBlockAnimationComplete(row, col)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  BlocBuilder<GameBloc, GameState>(
                    buildWhen: (p, c) =>
                        p.undoStack.length != c.undoStack.length ||
                        p.undosRemaining != c.undosRemaining,
                    builder: (context, state) => GameControls(
                      undosRemaining: state.undosRemaining,
                      onUndo: () =>
                          context.read<GameBloc>().add(const UndoMove()),
                      onHint: () =>
                          context.read<GameBloc>().add(const RequestHint()),
                      onClear: () {},
                    ),
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<GameBloc, GameState>(
                    buildWhen: (p, c) =>
                        p.selectedSymbol != c.selectedSymbol ||
                        p.board != c.board,
                    builder: (context, state) => NumberPanel(
                      boardSize: widget.puzzle.size,
                      selectedSymbol: state.selectedSymbol,
                      remainingCounts: _computeRemaining(
                          state.board, widget.puzzle.size),
                      onSymbolSelected: (sym) =>
                          context.read<GameBloc>().add(SelectSymbol(sym)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (widget.puzzle.tutorialStep != null)
              TutorialOverlay(message: widget.puzzle.tutorialStep!),
          ],
        ),
      ),
    );
  }

  void _showPauseMenu(BuildContext context) {
    context.read<GameBloc>().add(const PauseGame());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocBuilder<SettingsBloc, SettingsState>(
        builder: (ctx, settings) => AlertDialog(
          title: const Text('Paused'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Dark mode'),
                value: settings.theme == 'dark',
                onChanged: (v) => ctx.read<SettingsBloc>().add(
                      ChangeTheme(v ? 'dark' : 'light'),
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (context.mounted) {
                  context.read<GameBloc>().add(const ResumeGame());
                }
              },
              child: const Text('Resume'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (context.mounted) {
                  context.read<GameBloc>().add(const RestartPuzzle());
                }
              },
              child: const Text('Restart'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Quit'),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _computeRemaining(Board board, int size) {
    final counts = <String, int>{};
    for (final sym in SymbolSystem.forSize(size)) {
      final v = SymbolSystem.toValue(sym);
      var placed = 0;
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (board.cellAt(r, c).value == v) placed++;
        }
      }
      counts[sym] = size - placed;
    }
    return counts;
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (p, c) => p.board != c.board,
      builder: (context, state) {
        final board = state.board;
        var total = 0;
        var filled = 0;
        for (var r = 0; r < board.size; r++) {
          for (var c = 0; c < board.size; c++) {
            final cell = board.cellAt(r, c);
            if (!cell.isFixed && !cell.isIceBlock) {
              total++;
              if (cell.hasNumber) filled++;
            }
          }
        }
        final progress = total == 0 ? 0.0 : filled / total;
        final color = progress < 0.5
            ? Colors.green
            : progress < 0.8
                ? Colors.amber
                : Colors.deepOrange;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        );
      },
    );
  }
}

class _TimerRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (p, c) => p.elapsedSeconds != c.elapsedSeconds,
      builder: (context, state) {
        final m = state.elapsedSeconds ~/ 60;
        final s = state.elapsedSeconds % 60;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}  •  ${state.moveCount} moves',
            style: const TextStyle(fontSize: 14),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Run full analyze**

Run: `D:\flutter\bin\flutter.bat analyze lib/`
Expected: no errors

- [ ] **Step 3: Run all tests**

Run: `D:\flutter\bin\flutter.bat test -v`
Expected: All tests PASS

- [ ] **Step 4: Start the dev server and test visually**

Run: `D:\flutter\bin\flutter.bat run -d web-server --web-port 3456`

Open `http://localhost:3456` and verify:
- Progress bar appears below hearts, fills smoothly as numbers are placed
- Numbers animate downward (trajectory) when placed correctly
- The landed cell bounces (scale pulse) when a number arrives
- If the puzzle has ice blocks and you fill an entire row/column containing an ice block, it shatters and disappears
- Tutorial mode: no hearts, no progress bar, animations still play
- Restart (from pause menu or game-over screen): no crash, animations reset

- [ ] **Step 5: Commit**

```
git add lib/presentation/screens/game/game_screen.dart
git commit -m "feat: add progress bar; wire FallingNumberOverlay and ice-unlock animation in game_screen"
```
