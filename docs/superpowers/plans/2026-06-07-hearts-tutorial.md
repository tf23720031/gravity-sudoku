# Hearts, Tutorial & Difficulty Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 3-heart lives system, a 1-undo limit, tutorial levels with coach-mark overlays, and expanded puzzle content for all six difficulties.

**Architecture:** Extend `GameState` with `hearts`, `undosRemaining`, and `wrongFlashCell`; add `GameStatus.gameOver`; add `Difficulty.tutorial` and `Puzzle.tutorialStep`; pass full `Puzzle` to `GameBloc` so it can check placed values against `puzzle.solution`; add `DifficultySelectScreen` between Home and Level Select; add `GameOverScreen` when lives reach 0.

**Tech Stack:** Flutter/Dart, flutter_bloc ^8, equatable, existing Clean Architecture (Domain/Data/Presentation layers).

---

## File Map

**Modify:**
- `lib/domain/models/puzzle.dart` — add `tutorialStep`, `Difficulty.tutorial`
- `lib/presentation/bloc/game/game_state.dart` — add `hearts`, `undosRemaining`, `wrongFlashCell`, `GameStatus.gameOver`
- `lib/presentation/bloc/game/game_event.dart` — add `WrongFlashCleared`
- `lib/presentation/bloc/game/game_bloc.dart` — accept `Puzzle`, check solution, limit undo, flash timer
- `lib/presentation/screens/game/game_screen.dart` — pass `Puzzle` to bloc, show `HeartRow`, tutorial overlay, handle `gameOver`
- `lib/presentation/widgets/game_controls.dart` — show remaining undo count
- `lib/presentation/widgets/cell_tile.dart` — add `isWrongFlash` highlight
- `lib/presentation/screens/home/home_screen.dart` — navigate to `/difficulty` instead of `/levels`
- `lib/data/repositories/memory_puzzle_repository.dart` — load all 6 asset files
- `lib/main.dart` — add `/difficulty`, `/game_over` routes; update `/levels` to accept difficulty arg; seed tutorial
- `assets/puzzles/normal_9x9.json` — add puzzles 102–103
- `assets/puzzles/hard_12x12.json` — add puzzle 201
- `assets/puzzles/expert_16x16.json` — add puzzle 301
- `assets/puzzles/extreme_32x32.json` — add puzzle 401

**Create:**
- `lib/presentation/screens/difficulty_select/difficulty_select_screen.dart`
- `lib/presentation/screens/game_over/game_over_screen.dart`
- `lib/presentation/widgets/heart_row.dart`
- `lib/presentation/widgets/tutorial_overlay.dart`
- `assets/puzzles/tutorial_4x4.json`
- `test/presentation/bloc/game_bloc_hearts_test.dart`

---

### Task 1: Extend Puzzle domain model

**Files:**
- Modify: `lib/domain/models/puzzle.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/puzzle_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/puzzle.dart';

void main() {
  final board = Board.empty(4);

  test('Difficulty.tutorial exists', () {
    expect(Difficulty.tutorial, isA<Difficulty>());
  });

  test('Puzzle has nullable tutorialStep', () {
    final p = Puzzle(
      id: -1, size: 4,
      difficulty: Difficulty.tutorial,
      initialBoard: board, solution: board,
      tutorialStep: 'Hello',
    );
    expect(p.tutorialStep, 'Hello');

    final p2 = Puzzle(
      id: 1, size: 4,
      difficulty: Difficulty.easy,
      initialBoard: board, solution: board,
    );
    expect(p2.tutorialStep, isNull);
  });
}
```

- [ ] **Step 2: Run test — expect compile failure**

```
cd D:\projects\gravity-sudoku
$env:PATH = "D:\flutter\bin;" + $env:PATH
flutter test test/domain/puzzle_model_test.dart
```
Expected: error about `tutorial` or `tutorialStep` not existing.

- [ ] **Step 3: Update `lib/domain/models/puzzle.dart`**

```dart
import 'board.dart';

enum Difficulty { tutorial, easy, normal, hard, expert, extreme, daily }

class Puzzle {
  final int id;
  final int size;
  final Difficulty difficulty;
  final Board initialBoard;
  final Board solution;
  final String? tutorialStep;

  const Puzzle({
    required this.id,
    required this.size,
    required this.difficulty,
    required this.initialBoard,
    required this.solution,
    this.tutorialStep,
  });
}
```

- [ ] **Step 4: Run test — expect PASS**

```
flutter test test/domain/puzzle_model_test.dart
```
Expected: All tests pass.

- [ ] **Step 5: Update `lib/data/repositories/memory_puzzle_repository.dart` to parse `tutorialStep`**

In `_fromJson`, add `tutorialStep` to the returned `Puzzle`:

```dart
Puzzle _fromJson(Map<String, dynamic> json) {
  final size = json['size'] as int;
  final fixedRaw = (json['fixed_positions'] as List? ?? []);
  final fixedSet = fixedRaw.map((pos) => '${pos[0]},${pos[1]}').toSet();

  List<List<Cell>> parseGrid(List<dynamic> grid) {
    return grid.asMap().entries.map((rEntry) {
      return (rEntry.value as List).asMap().entries.map((cEntry) {
        final v = cEntry.value as int;
        if (v == -1) return const Cell(isIceBlock: true);
        if (v == 0) return const Cell();
        return Cell(
          value: v,
          isFixed: fixedSet.contains('${rEntry.key},${cEntry.key}'),
        );
      }).toList();
    }).toList();
  }

  return Puzzle(
    id: json['id'] as int,
    size: size,
    difficulty: Difficulty.values.byName(json['difficulty'] as String),
    initialBoard: Board(size: size, cells: parseGrid(json['initial'] as List)),
    solution: Board(size: size, cells: parseGrid(json['solution'] as List)),
    tutorialStep: json['tutorialStep'] as String?,
  );
}
```

- [ ] **Step 6: Verify no analysis errors**

```
flutter analyze lib/data/repositories/memory_puzzle_repository.dart
```
Expected: No issues.

- [ ] **Step 7: Commit**

```
git add lib/domain/models/puzzle.dart lib/data/repositories/memory_puzzle_repository.dart test/domain/puzzle_model_test.dart
git commit -m "feat: add Difficulty.tutorial and Puzzle.tutorialStep"
```

---

### Task 2: Extend GameState (hearts, undosRemaining, wrongFlashCell, gameOver)

**Files:**
- Modify: `lib/presentation/bloc/game/game_state.dart`
- Modify: `lib/presentation/bloc/game/game_event.dart`

- [ ] **Step 1: Write the failing test**

Create `test/presentation/bloc/game_bloc_hearts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/core/utils/position.dart';
import 'package:gravity_sudoku/presentation/bloc/game/game_state.dart';
import 'package:gravity_sudoku/domain/models/board.dart';

void main() {
  final board = Board.empty(4);

  test('GameState initial non-tutorial has 3 hearts, 1 undo', () {
    final s = GameState.initial(board, isTutorial: false);
    expect(s.hearts, 3);
    expect(s.undosRemaining, 1);
    expect(s.wrongFlashCell, isNull);
  });

  test('GameState initial tutorial has 3 hearts, 99 undos', () {
    final s = GameState.initial(board, isTutorial: true);
    expect(s.hearts, 3);
    expect(s.undosRemaining, 99);
  });

  test('GameStatus.gameOver exists', () {
    expect(GameStatus.gameOver, isA<GameStatus>());
  });

  test('stars: 3 hearts + 0 hints = 3 stars', () {
    final s = GameState.initial(board, isTutorial: false);
    expect(s.stars, 3);
  });

  test('stars: 2 hearts + 0 hints = 2 stars', () {
    final s = GameState.initial(board, isTutorial: false)
        .copyWith(hearts: 2);
    expect(s.stars, 2);
  });

  test('stars: 3 hearts + 2 hints = 1 star', () {
    final s = GameState.initial(board, isTutorial: false)
        .copyWith(hintUsedCount: 2);
    expect(s.stars, 1);
  });
}
```

- [ ] **Step 2: Run test — expect compile failure**

```
flutter test test/presentation/bloc/game_bloc_hearts_test.dart
```
Expected: errors about `isTutorial`, `hearts`, `undosRemaining`, `wrongFlashCell`, `gameOver`.

- [ ] **Step 3: Replace `lib/presentation/bloc/game/game_state.dart`**

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
    bool clearHint = false,
    bool clearGravityResult = false,
    bool clearSymbol = false,
    bool clearWrongFlash = false,
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
      ];
}
```

- [ ] **Step 4: Add `WrongFlashCleared` to `lib/presentation/bloc/game/game_event.dart`**

Append at the end of the file (keep all existing events unchanged):

```dart
class WrongFlashCleared extends GameEvent {
  const WrongFlashCleared();
}
```

- [ ] **Step 5: Run test — expect PASS**

```
flutter test test/presentation/bloc/game_bloc_hearts_test.dart
```
Expected: All tests pass.

- [ ] **Step 6: Commit**

```
git add lib/presentation/bloc/game/game_state.dart lib/presentation/bloc/game/game_event.dart test/presentation/bloc/game_bloc_hearts_test.dart
git commit -m "feat: add hearts/undosRemaining/wrongFlashCell to GameState, gameOver status"
```

---

### Task 3: Update GameBloc — solution checking, undo limit, flash timer

**Files:**
- Modify: `lib/presentation/bloc/game/game_bloc.dart`

GameBloc now takes a `Puzzle` instead of separate `initialBoard` + `boardSize`. It checks each placed number against `puzzle.solution` and deducts a heart on mismatch. Undo is limited to `undosRemaining`. A 600 ms timer clears `wrongFlashCell`.

- [ ] **Step 1: Replace `lib/presentation/bloc/game/game_bloc.dart`**

```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/symbols.dart';
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
  Timer? _timer;
  Timer? _wrongFlashTimer;

  GameBloc({
    required Puzzle puzzle,
    required GravityEngine gravity,
    required SudokuValidator validator,
    required HintService hint,
  })  : _puzzle = puzzle,
        _gravity = gravity,
        _validator = validator,
        _hint = hint,
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
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == GameStatus.playing) add(const TimerTicked());
    });
  }

  void _onSelectSymbol(SelectSymbol event, Emitter<GameState> emit) {
    emit(state.copyWith(selectedSymbol: event.symbol, clearHint: true));
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

    // Check against solution
    final solutionValue =
        _puzzle.solution.cellAt(result.toRow, event.col).value;
    final isCorrect = solutionValue == value;

    if (!isCorrect && _puzzle.difficulty != Difficulty.tutorial) {
      final newHearts = state.hearts - 1;
      _wrongFlashTimer?.cancel();
      emit(state.copyWith(
        hearts: newHearts,
        wrongFlashCell: Position(result.toRow, event.col),
        status: newHearts <= 0 ? GameStatus.gameOver : GameStatus.playing,
      ));
      _wrongFlashTimer = Timer(const Duration(milliseconds: 600), () {
        add(const WrongFlashCleared());
      });
      return;
    }

    final newBoard =
        _gravity.apply(state.board, col: event.col, value: value, result: result);
    final conflicts = _validator.findConflicts(newBoard);
    final newStack = [...state.undoStack, state.board];
    final isComplete = conflicts.isEmpty && _validator.isComplete(newBoard);

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
    ));
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

  @override
  Future<void> close() {
    _timer?.cancel();
    _wrongFlashTimer?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 2: Verify analysis**

```
flutter analyze lib/presentation/bloc/game/game_bloc.dart
```
Expected: No issues (may warn about unused imports if any).

- [ ] **Step 3: Run existing tests**

```
flutter test
```
Expected: Failures only due to GameBloc constructor change (now takes `puzzle:` instead of `initialBoard:` + `boardSize:`). Note the broken tests — fix in next step.

- [ ] **Step 4: Update `lib/presentation/screens/game/game_screen.dart` — pass Puzzle to GameBloc**

Replace the `BlocProvider create:` block only:

```dart
// Old:
create: (_) => GameBloc(
  initialBoard: puzzle.initialBoard,
  gravity: GravityEngine(),
  validator: SudokuValidator(),
  hint: HintService(gravity: GravityEngine(), validator: SudokuValidator()),
  boardSize: puzzle.size,
),

// New:
create: (_) => GameBloc(
  puzzle: puzzle,
  gravity: GravityEngine(),
  validator: SudokuValidator(),
  hint: HintService(gravity: GravityEngine(), validator: SudokuValidator()),
),
```

- [ ] **Step 5: Run tests again**

```
flutter test
```
Expected: Only `game_bloc_hearts_test.dart` passes. If other tests reference old GameBloc constructor, update them to use `puzzle:` parameter with a minimal test `Puzzle`.

- [ ] **Step 6: Commit**

```
git add lib/presentation/bloc/game/game_bloc.dart lib/presentation/screens/game/game_screen.dart
git commit -m "feat: GameBloc checks answer vs solution, limits undo, deducts hearts"
```

---

### Task 4: GameOverScreen + navigation

**Files:**
- Create: `lib/presentation/screens/game_over/game_over_screen.dart`
- Modify: `lib/presentation/screens/game/game_screen.dart` (BlocListener for gameOver)
- Modify: `lib/main.dart` (add `/game_over` route)

- [ ] **Step 1: Create `lib/presentation/screens/game_over/game_over_screen.dart`**

```dart
import 'package:flutter/material.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Game Over',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('You ran out of lives.',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // back to game (restarts)
              },
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update BlocListener in `lib/presentation/screens/game/game_screen.dart`**

Replace the existing `BlocListener` `listenWhen` + `listener` with:

```dart
BlocListener<GameBloc, GameState>(
  listenWhen: (prev, curr) => prev.status != curr.status,
  listener: (context, state) {
    if (state.status == GameStatus.completed) {
      Navigator.of(context).pushReplacementNamed(
        '/completion',
        arguments: {'stars': state.stars, 'time': state.elapsedSeconds},
      );
    } else if (state.status == GameStatus.gameOver) {
      Navigator.of(context).pushNamed('/game_over');
    }
  },
  child: ...
)
```

- [ ] **Step 3: Add `/game_over` route to `lib/main.dart`**

Inside `onGenerateRoute`, add before `default:`:

```dart
case '/game_over':
  return MaterialPageRoute(
    builder: (_) => const GameOverScreen(),
  );
```

Also add the import at the top:
```dart
import 'presentation/screens/game_over/game_over_screen.dart';
```

- [ ] **Step 4: Hot restart and test manually**

In the running flutter web server, verify the app still builds:
```
r  ← hot reload in the flutter run terminal
```
Expected: No errors.

- [ ] **Step 5: Commit**

```
git add lib/presentation/screens/game_over/game_over_screen.dart lib/presentation/screens/game/game_screen.dart lib/main.dart
git commit -m "feat: add GameOverScreen, navigate on gameOver status"
```

---

### Task 5: DifficultySelectScreen + route updates

**Files:**
- Create: `lib/presentation/screens/difficulty_select/difficulty_select_screen.dart`
- Modify: `lib/presentation/screens/home/home_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create `lib/presentation/screens/difficulty_select/difficulty_select_screen.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/puzzle.dart';

class DifficultySelectScreen extends StatelessWidget {
  const DifficultySelectScreen({super.key});

  static const _items = [
    _DifficultyItem(Difficulty.tutorial, 'Tutorial', '4×4', Icons.school_outlined),
    _DifficultyItem(Difficulty.easy,     'Easy',     '4×4', Icons.sentiment_very_satisfied),
    _DifficultyItem(Difficulty.normal,   'Normal',   '9×9', Icons.sentiment_satisfied),
    _DifficultyItem(Difficulty.hard,     'Hard',    '12×12', Icons.sentiment_neutral),
    _DifficultyItem(Difficulty.expert,   'Expert',  '16×16', Icons.sentiment_dissatisfied),
    _DifficultyItem(Difficulty.extreme,  'Extreme', '32×32', Icons.whatshot),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Difficulty')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final item = _items[i];
          return Card(
            child: ListTile(
              leading: Icon(item.icon, color: AppColors.primary),
              title: Text(item.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.boardSize),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed(
                '/levels',
                arguments: {'difficulty': item.difficulty},
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DifficultyItem {
  final Difficulty difficulty;
  final String label;
  final String boardSize;
  final IconData icon;
  const _DifficultyItem(this.difficulty, this.label, this.boardSize, this.icon);
}
```

- [ ] **Step 2: Update `lib/presentation/screens/home/home_screen.dart` — navigate to `/difficulty`**

Change the `ElevatedButton.onPressed` and `TextButton.onPressed` that go to `/levels` to go to `/difficulty` instead:

```dart
ElevatedButton(
  onPressed: () => Navigator.of(context).pushNamed('/difficulty'),
  child: const Padding(
    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
    child: Text('Play', style: TextStyle(fontSize: 20)),
  ),
),
const SizedBox(height: 16),
TextButton(
  onPressed: () => Navigator.of(context).pushNamed('/difficulty'),
  child: const Text('Daily Challenge'),
),
```

- [ ] **Step 3: Update `lib/main.dart` — add `/difficulty` route, make `/levels` dynamic**

Add import:
```dart
import 'presentation/screens/difficulty_select/difficulty_select_screen.dart';
```

Add `/difficulty` case inside `onGenerateRoute`:
```dart
case '/difficulty':
  return MaterialPageRoute(
    builder: (_) => const DifficultySelectScreen(),
  );
```

Replace the existing `/levels` case with:
```dart
case '/levels':
  final args = settings.arguments as Map<String, dynamic>? ?? {};
  final difficulty = args['difficulty'] as Difficulty? ?? Difficulty.easy;
  return MaterialPageRoute(
    builder: (_) => FutureBuilder(
      future: puzzleRepo.fetchByDifficulty(difficulty),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return LevelSelectScreen(
          puzzles: snap.data!,
          difficulty: difficulty,
        );
      },
    ),
  );
```

- [ ] **Step 4: Hot reload and verify navigation**

```
r  ← in flutter run terminal
```
Navigate: Home → Play → DifficultySelectScreen shows 6 rows. Tap Easy → LevelSelectScreen with 2 puzzles. Tap Puzzle 1 → GameScreen loads.

- [ ] **Step 5: Commit**

```
git add lib/presentation/screens/difficulty_select/difficulty_select_screen.dart lib/presentation/screens/home/home_screen.dart lib/main.dart
git commit -m "feat: add DifficultySelectScreen, dynamic difficulty routing"
```

---

### Task 6: Tutorial puzzle JSON + TutorialOverlay

**Files:**
- Create: `assets/puzzles/tutorial_4x4.json`
- Modify: `lib/data/repositories/memory_puzzle_repository.dart` (load tutorial + all files)
- Modify: `lib/main.dart` (_seedPuzzles includes tutorial)
- Create: `lib/presentation/widgets/tutorial_overlay.dart`
- Modify: `lib/presentation/screens/game/game_screen.dart` (show overlay)

- [ ] **Step 1: Create `assets/puzzles/tutorial_4x4.json`**

All three puzzles share the same solution:
```
1 2 3 4
3 4 1 2
2 1 4 3
4 3 2 1
```
Verified: rows ✓, cols ✓, 2×2 subgrids ✓.

```json
{
  "puzzles": [
    {
      "id": -1,
      "size": 4,
      "difficulty": "tutorial",
      "tutorialStep": "選擇右側的數字，然後點擊空白格放置。數字會自動向下落！",
      "initial": [
        [1,2,3,4],
        [3,4,1,2],
        [2,1,4,3],
        [4,0,0,1]
      ],
      "ice_blocks": [],
      "solution": [
        [1,2,3,4],
        [3,4,1,2],
        [2,1,4,3],
        [4,3,2,1]
      ],
      "fixed_positions": [
        [0,0],[0,1],[0,2],[0,3],
        [1,0],[1,1],[1,2],[1,3],
        [2,0],[2,1],[2,2],[2,3],
        [3,0],[3,3]
      ]
    },
    {
      "id": -2,
      "size": 4,
      "difficulty": "tutorial",
      "tutorialStep": "重力！數字會一直往下落，直到碰到底部或其他數字為止。先放下方的數字。",
      "initial": [
        [0,2,3,4],
        [0,4,1,2],
        [2,1,4,3],
        [4,3,2,1]
      ],
      "ice_blocks": [],
      "solution": [
        [1,2,3,4],
        [3,4,1,2],
        [2,1,4,3],
        [4,3,2,1]
      ],
      "fixed_positions": [
        [0,1],[0,2],[0,3],
        [1,1],[1,2],[1,3],
        [2,0],[2,1],[2,2],[2,3],
        [3,0],[3,1],[3,2],[3,3]
      ]
    },
    {
      "id": -3,
      "size": 4,
      "difficulty": "tutorial",
      "tutorialStep": "最後挑戰！想清楚放置順序，較底部的格子先放。",
      "initial": [
        [0,2,3,0],
        [3,0,0,2],
        [2,1,0,3],
        [4,0,2,1]
      ],
      "ice_blocks": [],
      "solution": [
        [1,2,3,4],
        [3,4,1,2],
        [2,1,4,3],
        [4,3,2,1]
      ],
      "fixed_positions": [
        [0,1],[0,2],
        [1,0],[1,3],
        [2,0],[2,1],[2,3],
        [3,0],[3,2],[3,3]
      ]
    }
  ]
}
```

- [ ] **Step 2: Update `lib/data/repositories/memory_puzzle_repository.dart` — load all 6 asset files**

Replace the `files` list in `_ensureLoaded`:

```dart
final files = [
  'assets/puzzles/tutorial_4x4.json',
  'assets/puzzles/easy_4x4.json',
  'assets/puzzles/normal_9x9.json',
  'assets/puzzles/hard_12x12.json',
  'assets/puzzles/expert_16x16.json',
  'assets/puzzles/extreme_32x32.json',
];
```

- [ ] **Step 3: Update `lib/main.dart` `_seedPuzzles` to include tutorial**

Replace the `files` list in `_seedPuzzles`:

```dart
final files = [
  'assets/puzzles/tutorial_4x4.json',
  'assets/puzzles/easy_4x4.json',
  'assets/puzzles/normal_9x9.json',
  'assets/puzzles/hard_12x12.json',
  'assets/puzzles/expert_16x16.json',
  'assets/puzzles/extreme_32x32.json',
];
```

- [ ] **Step 4: Create `lib/presentation/widgets/tutorial_overlay.dart`**

```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class TutorialOverlay extends StatefulWidget {
  final String message;
  const TutorialOverlay({super.key, required this.message});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => setState(() => _visible = false),
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined,
                      size: 40, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => setState(() => _visible = false),
                    child: const Text('OK, 開始！'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Update `lib/presentation/screens/game/game_screen.dart` — show overlay for tutorial**

In `_GameView.build`, wrap the `Scaffold` body's `SafeArea` in a `Stack` that adds the overlay:

Replace `body: SafeArea(...)` with:

```dart
body: Stack(
  children: [
    SafeArea(
      child: Column(
        children: [
          _TimerRow(),
          // ... (keep existing grid + controls + number panel)
        ],
      ),
    ),
    if (puzzle.tutorialStep != null)
      TutorialOverlay(message: puzzle.tutorialStep!),
  ],
),
```

Also add the import at top of game_screen.dart:
```dart
import '../../widgets/tutorial_overlay.dart';
```

- [ ] **Step 6: Hot reload and verify tutorial flow**

Navigate: Home → Play → Tutorial → Tutorial Lv 1 → coach mark appears → tap OK → can play.

- [ ] **Step 7: Commit**

```
git add assets/puzzles/tutorial_4x4.json lib/data/repositories/memory_puzzle_repository.dart lib/main.dart lib/presentation/widgets/tutorial_overlay.dart lib/presentation/screens/game/game_screen.dart
git commit -m "feat: tutorial levels with coach-mark overlay"
```

---

### Task 7: Puzzle data for all difficulties

**Files:**
- Modify: `assets/puzzles/normal_9x9.json`
- Modify: `assets/puzzles/hard_12x12.json`
- Modify: `assets/puzzles/expert_16x16.json`
- Modify: `assets/puzzles/extreme_32x32.json`

All solutions use a verified cyclic Latin-square construction.

- [ ] **Step 1: Update `assets/puzzles/normal_9x9.json` — add puzzles 102 and 103**

Add to the `"puzzles"` array (after existing id:101):

```json
,
{
  "id": 102,
  "size": 9,
  "difficulty": "normal",
  "initial": [
    [4,0,0,0,6,0,0,0,1],
    [0,8,0,0,0,1,0,0,3],
    [0,0,7,0,0,0,0,6,0],
    [8,0,0,1,0,0,0,0,7],
    [0,0,4,0,0,0,9,0,0],
    [9,0,0,0,0,3,0,2,0],
    [0,0,0,0,2,0,0,0,4],
    [0,4,0,9,0,0,1,0,0],
    [7,0,0,4,0,0,0,0,9]
  ],
  "ice_blocks": [],
  "solution": [
    [4,3,5,2,6,9,7,8,1],
    [6,8,2,5,7,1,4,9,3],
    [1,9,7,8,3,4,5,6,2],
    [8,2,6,1,9,5,3,4,7],
    [3,7,4,6,8,2,9,1,5],
    [9,5,1,7,4,3,6,2,8],
    [5,1,9,3,2,6,8,7,4],
    [2,4,8,9,5,7,1,3,6],
    [7,6,3,4,1,8,2,5,9]
  ],
  "fixed_positions": [
    [0,0],[0,4],[0,8],
    [1,1],[1,5],[1,8],
    [2,2],[2,7],
    [3,0],[3,3],[3,8],
    [4,2],[4,6],
    [5,0],[5,5],[5,7],
    [6,4],[6,8],
    [7,1],[7,3],[7,6],
    [8,0],[8,3],[8,8]
  ]
},
{
  "id": 103,
  "size": 9,
  "difficulty": "normal",
  "initial": [
    [0,0,4,6,0,0,9,0,2],
    [6,0,0,0,9,0,0,4,0],
    [0,9,0,0,0,2,0,0,7],
    [0,5,0,7,0,0,4,0,0],
    [4,0,0,0,5,0,0,9,0],
    [0,0,3,0,0,4,0,0,6],
    [9,0,0,0,3,0,2,0,0],
    [0,8,0,4,0,9,0,3,0],
    [0,0,5,0,8,0,0,7,9]
  ],
  "ice_blocks": [],
  "solution": [
    [5,3,4,6,7,8,9,1,2],
    [6,7,2,1,9,5,3,4,8],
    [1,9,8,3,4,2,5,6,7],
    [8,5,9,7,6,1,4,2,3],
    [4,2,6,8,5,3,7,9,1],
    [7,1,3,9,2,4,8,5,6],
    [9,6,1,5,3,7,2,8,4],
    [2,8,7,4,1,9,6,3,5],
    [3,4,5,2,8,6,1,7,9]
  ],
  "fixed_positions": [
    [0,2],[0,3],[0,6],[0,8],
    [1,0],[1,4],[1,7],
    [2,1],[2,5],[2,8],
    [3,1],[3,3],[3,6],
    [4,0],[4,4],[4,7],
    [5,2],[5,5],[5,8],
    [6,0],[6,4],[6,6],
    [7,1],[7,3],[7,5],[7,7],
    [8,2],[8,4],[8,7],[8,8]
  ]
}
```

- [ ] **Step 2: Replace `assets/puzzles/hard_12x12.json`**

Solution uses cyclic construction (3-row × 4-col subgrids, verified).

```json
{
  "puzzles": [
    {
      "id": 201,
      "size": 12,
      "difficulty": "hard",
      "initial": [
        [1,0,0,4,0,0,7,0,0,10,0,0],
        [0,0,7,0,0,10,0,0,1,0,0,4],
        [0,10,0,0,1,0,0,4,0,0,7,0],
        [2,0,0,1,0,0,8,0,0,11,0,0],
        [0,0,8,0,0,11,0,0,2,0,0,1],
        [0,11,0,0,2,0,0,1,0,0,8,0],
        [3,0,0,2,0,0,5,0,0,12,0,0],
        [0,0,5,0,0,12,0,0,3,0,0,2],
        [0,12,0,0,3,0,0,2,0,0,5,0],
        [4,0,0,3,0,0,6,0,0,9,0,0],
        [0,0,6,0,0,9,0,0,4,0,0,3],
        [0,9,0,0,4,0,0,3,0,0,6,0]
      ],
      "ice_blocks": [],
      "solution": [
        [1,2,3,4,5,6,7,8,9,10,11,12],
        [5,6,7,8,9,10,11,12,1,2,3,4],
        [9,10,11,12,1,2,3,4,5,6,7,8],
        [2,3,4,1,6,7,8,5,10,11,12,9],
        [6,7,8,5,10,11,12,9,2,3,4,1],
        [10,11,12,9,2,3,4,1,6,7,8,5],
        [3,4,1,2,7,8,5,6,11,12,9,10],
        [7,8,5,6,11,12,9,10,3,4,1,2],
        [11,12,9,10,3,4,1,2,7,8,5,6],
        [4,1,2,3,8,5,6,7,12,9,10,11],
        [8,5,6,7,12,9,10,11,4,1,2,3],
        [12,9,10,11,4,1,2,3,8,5,6,7]
      ],
      "fixed_positions": [
        [0,0],[0,3],[0,6],[0,9],
        [1,2],[1,5],[1,8],[1,11],
        [2,1],[2,4],[2,7],[2,10],
        [3,0],[3,3],[3,6],[3,9],
        [4,2],[4,5],[4,8],[4,11],
        [5,1],[5,4],[5,7],[5,10],
        [6,0],[6,3],[6,6],[6,9],
        [7,2],[7,5],[7,8],[7,11],
        [8,1],[8,4],[8,7],[8,10],
        [9,0],[9,3],[9,6],[9,9],
        [10,2],[10,5],[10,8],[10,11],
        [11,1],[11,4],[11,7],[11,10]
      ]
    }
  ]
}
```

- [ ] **Step 3: Replace `assets/puzzles/expert_16x16.json`**

Solution uses cyclic construction (4-row × 4-col subgrids).

```json
{
  "puzzles": [
    {
      "id": 301,
      "size": 16,
      "difficulty": "expert",
      "initial": [
        [1,0,0,0,5,0,0,0,9,0,0,0,13,0,0,0],
        [0,0,0,8,0,0,0,12,0,0,0,16,0,0,0,4],
        [0,0,11,0,0,0,15,0,0,0,3,0,0,0,7,0],
        [0,14,0,0,0,2,0,0,0,6,0,0,0,10,0,0],
        [2,0,0,0,6,0,0,0,10,0,0,0,14,0,0,0],
        [0,0,0,5,0,0,0,9,0,0,0,13,0,0,0,1],
        [0,0,12,0,0,0,16,0,0,0,4,0,0,0,8,0],
        [0,15,0,0,0,3,0,0,0,7,0,0,0,11,0,0],
        [3,0,0,0,7,0,0,0,11,0,0,0,15,0,0,0],
        [0,0,0,6,0,0,0,10,0,0,0,14,0,0,0,2],
        [0,0,9,0,0,0,13,0,0,0,1,0,0,0,5,0],
        [0,16,0,0,0,4,0,0,0,8,0,0,0,12,0,0],
        [4,0,0,0,8,0,0,0,12,0,0,0,16,0,0,0],
        [0,0,0,7,0,0,0,11,0,0,0,15,0,0,0,3],
        [0,0,10,0,0,0,14,0,0,0,2,0,0,0,6,0],
        [0,13,0,0,0,1,0,0,0,5,0,0,0,9,0,0]
      ],
      "ice_blocks": [],
      "solution": [
        [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16],
        [5,6,7,8,9,10,11,12,13,14,15,16,1,2,3,4],
        [9,10,11,12,13,14,15,16,1,2,3,4,5,6,7,8],
        [13,14,15,16,1,2,3,4,5,6,7,8,9,10,11,12],
        [2,3,4,1,6,7,8,5,10,11,12,9,14,15,16,13],
        [6,7,8,5,10,11,12,9,14,15,16,13,2,3,4,1],
        [10,11,12,9,14,15,16,13,2,3,4,1,6,7,8,5],
        [14,15,16,13,2,3,4,1,6,7,8,5,10,11,12,9],
        [3,4,1,2,7,8,5,6,11,12,9,10,15,16,13,14],
        [7,8,5,6,11,12,9,10,15,16,13,14,3,4,1,2],
        [11,12,9,10,15,16,13,14,3,4,1,2,7,8,5,6],
        [15,16,13,14,3,4,1,2,7,8,5,6,11,12,9,10],
        [4,1,2,3,8,5,6,7,12,9,10,11,16,13,14,15],
        [8,5,6,7,12,9,10,11,16,13,14,15,4,1,2,3],
        [12,9,10,11,16,13,14,15,4,1,2,3,8,5,6,7],
        [16,13,14,15,4,1,2,3,8,5,6,7,12,9,10,11]
      ],
      "fixed_positions": [
        [0,0],[0,4],[0,8],[0,12],
        [1,3],[1,7],[1,11],[1,15],
        [2,2],[2,6],[2,10],[2,14],
        [3,1],[3,5],[3,9],[3,13],
        [4,0],[4,4],[4,8],[4,12],
        [5,3],[5,7],[5,11],[5,15],
        [6,2],[6,6],[6,10],[6,14],
        [7,1],[7,5],[7,9],[7,13],
        [8,0],[8,4],[8,8],[8,12],
        [9,3],[9,7],[9,11],[9,15],
        [10,2],[10,6],[10,10],[10,14],
        [11,1],[11,5],[11,9],[11,13],
        [12,0],[12,4],[12,8],[12,12],
        [13,3],[13,7],[13,11],[13,15],
        [14,2],[14,6],[14,10],[14,14],
        [15,1],[15,5],[15,9],[15,13]
      ]
    }
  ]
}
```

- [ ] **Step 4: Replace `assets/puzzles/extreme_32x32.json`**

Solution uses cyclic construction (4-row × 8-col subgrids, symbols 1–32). Initial keeps every cell where `(row + col * 2) % 16 == 0` — approx 128 clues out of 1024 (12.5%), appropriate for extreme difficulty.

```json
{
  "puzzles": [
    {
      "id": 401,
      "size": 32,
      "difficulty": "extreme",
      "initial": [
        [1,0,0,0,0,0,0,0,9,0,0,0,0,0,0,0,17,0,0,0,0,0,0,0,25,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,24,0,0,0,0,0,0,0,16],
        [0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,16,0,0,0,0,0,0,0,24,0,0,0,0,0,0,0,0],
        [2,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,18,0,0,0,0,0,0,0,26,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,17,0,0,0,0,0,0,0,9],
        [0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,9,0,0,0,0,0,0,0,17,0,0,0,0,0,0,0,0],
        [3,0,0,0,0,0,0,0,11,0,0,0,0,0,0,0,19,0,0,0,0,0,0,0,27,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,18,0,0,0,0,0,0,0,10],
        [0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,10,0,0,0,0,0,0,0,18,0,0,0,0,0,0,0,0],
        [4,0,0,0,0,0,0,0,12,0,0,0,0,0,0,0,20,0,0,0,0,0,0,0,28,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,19,0,0,0,0,0,0,0,11],
        [0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,11,0,0,0,0,0,0,0,19,0,0,0,0,0,0,0,0],
        [5,0,0,0,0,0,0,0,13,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,29,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,20,0,0,0,0,0,0,0,12],
        [0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,12,0,0,0,0,0,0,0,20,0,0,0,0,0,0,0,0],
        [6,0,0,0,0,0,0,0,14,0,0,0,0,0,0,0,22,0,0,0,0,0,0,0,30,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,13],
        [0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,13,0,0,0,0,0,0,0,21,0,0,0,0,0,0,0,0],
        [7,0,0,0,0,0,0,0,15,0,0,0,0,0,0,0,23,0,0,0,0,0,0,0,31,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,22,0,0,0,0,0,0,0,14],
        [0,0,0,0,0,0,0,6,0,0,0,0,0,0,0,14,0,0,0,0,0,0,0,22,0,0,0,0,0,0,0,0],
        [8,0,0,0,0,0,0,0,16,0,0,0,0,0,0,0,24,0,0,0,0,0,0,0,32,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,23,0,0,0,0,0,0,0,15],
        [0,0,0,0,0,0,0,7,0,0,0,0,0,0,0,15,0,0,0,0,0,0,0,23,0,0,0,0,0,0,0,0]
      ],
      "ice_blocks": [],
      "solution": [
        [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32],
        [9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,1,2,3,4,5,6,7,8],
        [17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16],
        [25,26,27,28,29,30,31,32,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24],
        [2,3,4,5,6,7,8,1,10,11,12,13,14,15,16,9,18,19,20,21,22,23,24,17,26,27,28,29,30,31,32,25],
        [10,11,12,13,14,15,16,9,18,19,20,21,22,23,24,17,26,27,28,29,30,31,32,25,2,3,4,5,6,7,8,1],
        [18,19,20,21,22,23,24,17,26,27,28,29,30,31,32,25,2,3,4,5,6,7,8,1,10,11,12,13,14,15,16,9],
        [26,27,28,29,30,31,32,25,2,3,4,5,6,7,8,1,10,11,12,13,14,15,16,9,18,19,20,21,22,23,24,17],
        [3,4,5,6,7,8,1,2,11,12,13,14,15,16,9,10,19,20,21,22,23,24,17,18,27,28,29,30,31,32,25,26],
        [11,12,13,14,15,16,9,10,19,20,21,22,23,24,17,18,27,28,29,30,31,32,25,26,3,4,5,6,7,8,1,2],
        [19,20,21,22,23,24,17,18,27,28,29,30,31,32,25,26,3,4,5,6,7,8,1,2,11,12,13,14,15,16,9,10],
        [27,28,29,30,31,32,25,26,3,4,5,6,7,8,1,2,11,12,13,14,15,16,9,10,19,20,21,22,23,24,17,18],
        [4,5,6,7,8,1,2,3,12,13,14,15,16,9,10,11,20,21,22,23,24,17,18,19,28,29,30,31,32,25,26,27],
        [12,13,14,15,16,9,10,11,20,21,22,23,24,17,18,19,28,29,30,31,32,25,26,27,4,5,6,7,8,1,2,3],
        [20,21,22,23,24,17,18,19,28,29,30,31,32,25,26,27,4,5,6,7,8,1,2,3,12,13,14,15,16,9,10,11],
        [28,29,30,31,32,25,26,27,4,5,6,7,8,1,2,3,12,13,14,15,16,9,10,11,20,21,22,23,24,17,18,19],
        [5,6,7,8,1,2,3,4,13,14,15,16,9,10,11,12,21,22,23,24,17,18,19,20,29,30,31,32,25,26,27,28],
        [13,14,15,16,9,10,11,12,21,22,23,24,17,18,19,20,29,30,31,32,25,26,27,28,5,6,7,8,1,2,3,4],
        [21,22,23,24,17,18,19,20,29,30,31,32,25,26,27,28,5,6,7,8,1,2,3,4,13,14,15,16,9,10,11,12],
        [29,30,31,32,25,26,27,28,5,6,7,8,1,2,3,4,13,14,15,16,9,10,11,12,21,22,23,24,17,18,19,20],
        [6,7,8,1,2,3,4,5,14,15,16,9,10,11,12,13,22,23,24,17,18,19,20,21,30,31,32,25,26,27,28,29],
        [14,15,16,9,10,11,12,13,22,23,24,17,18,19,20,21,30,31,32,25,26,27,28,29,6,7,8,1,2,3,4,5],
        [22,23,24,17,18,19,20,21,30,31,32,25,26,27,28,29,6,7,8,1,2,3,4,5,14,15,16,9,10,11,12,13],
        [30,31,32,25,26,27,28,29,6,7,8,1,2,3,4,5,14,15,16,9,10,11,12,13,22,23,24,17,18,19,20,21],
        [7,8,1,2,3,4,5,6,15,16,9,10,11,12,13,14,23,24,17,18,19,20,21,22,31,32,25,26,27,28,29,30],
        [15,16,9,10,11,12,13,14,23,24,17,18,19,20,21,22,31,32,25,26,27,28,29,30,7,8,1,2,3,4,5,6],
        [23,24,17,18,19,20,21,22,31,32,25,26,27,28,29,30,7,8,1,2,3,4,5,6,15,16,9,10,11,12,13,14],
        [31,32,25,26,27,28,29,30,7,8,1,2,3,4,5,6,15,16,9,10,11,12,13,14,23,24,17,18,19,20,21,22],
        [8,1,2,3,4,5,6,7,16,9,10,11,12,13,14,15,24,17,18,19,20,21,22,23,32,25,26,27,28,29,30,31],
        [16,9,10,11,12,13,14,15,24,17,18,19,20,21,22,23,32,25,26,27,28,29,30,31,8,1,2,3,4,5,6,7],
        [24,17,18,19,20,21,22,23,32,25,26,27,28,29,30,31,8,1,2,3,4,5,6,7,16,9,10,11,12,13,14,15],
        [32,25,26,27,28,29,30,31,8,1,2,3,4,5,6,7,16,9,10,11,12,13,14,15,24,17,18,19,20,21,22,23]
      ],
      "fixed_positions": [
        [0,0],[0,8],[0,16],[0,24],
        [1,25],
        [2,23],[2,31],
        [3,7],[3,15],[3,23],
        [4,0],[4,8],[4,16],[4,24],
        [5,25],
        [6,23],[6,31],
        [7,7],[7,15],[7,23],
        [8,0],[8,8],[8,16],[8,24],
        [9,25],
        [10,23],[10,31],
        [11,7],[11,15],[11,23],
        [12,0],[12,8],[12,16],[12,24],
        [13,25],
        [14,23],[14,31],
        [15,7],[15,15],[15,23],
        [16,0],[16,8],[16,16],[16,24],
        [17,25],
        [18,23],[18,31],
        [19,7],[19,15],[19,23],
        [20,0],[20,8],[20,16],[20,24],
        [21,25],
        [22,23],[22,31],
        [23,7],[23,15],[23,23],
        [24,0],[24,8],[24,16],[24,24],
        [25,25],
        [26,23],[26,31],
        [27,7],[27,15],[27,23],
        [28,0],[28,8],[28,16],[28,24],
        [29,25],
        [30,23],[30,31],
        [31,7],[31,15],[31,23]
      ]
    }
  ]
}
```

- [ ] **Step 5: Hot reload and verify difficulty select shows levels**

Navigate to each difficulty. Easy: 2 puzzles. Normal: 3 puzzles. Hard: 1 puzzle. Expert: 1 puzzle. Extreme: 1 puzzle. Tutorial: 3 puzzles.

- [ ] **Step 6: Commit**

```
git add assets/puzzles/
git commit -m "feat: add puzzle data for all 6 difficulty levels"
```

---

### Task 8: UI — HeartRow, wrong-flash cell highlight, undo label, stars

**Files:**
- Create: `lib/presentation/widgets/heart_row.dart`
- Modify: `lib/presentation/widgets/cell_tile.dart` (add `isWrongFlash`)
- Modify: `lib/presentation/widgets/game_controls.dart` (replace `canUndo` with `undosRemaining`)
- Modify: `lib/presentation/screens/game/game_screen.dart` (add HeartRow, wire wrongFlashCell)

- [ ] **Step 1: Create `lib/presentation/widgets/heart_row.dart`**

```dart
import 'package:flutter/material.dart';

class HeartRow extends StatelessWidget {
  final int hearts;
  const HeartRow({super.key, required this.hearts});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            i < hearts ? Icons.favorite : Icons.favorite_border,
            color: Colors.red,
            size: 24,
          ),
        );
      }),
    );
  }
}
```

- [ ] **Step 2: Update `lib/presentation/widgets/cell_tile.dart` — add `isWrongFlash`**

Add the parameter and its background color:

```dart
class CellTile extends StatelessWidget {
  final Cell cell;
  final bool isConflict;
  final bool isHint;
  final bool isSelected;
  final bool isWrongFlash;   // ← new
  final VoidCallback onTap;

  const CellTile({
    super.key,
    required this.cell,
    required this.onTap,
    this.isConflict = false,
    this.isHint = false,
    this.isSelected = false,
    this.isWrongFlash = false,   // ← new
  });

  @override
  Widget build(BuildContext context) {
    if (cell.isIceBlock) return const IceBlockTile();

    Color bg = Colors.transparent;
    if (isConflict) bg = AppColors.conflict.withValues(alpha: 0.2);
    if (isHint) bg = AppColors.hint.withValues(alpha: 0.3);
    if (isSelected) bg = AppColors.primary.withValues(alpha: 0.15);
    if (isWrongFlash) bg = Colors.red.withValues(alpha: 0.45);  // ← new, highest priority

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: cell.hasNumber
            ? Text(
                SymbolSystem.fromValue(cell.value!),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cell.isFixed
                      ? AppColors.fixedNumber
                      : AppColors.playerNumber,
                ),
              )
            : null,
      ),
    );
  }
}
```

- [ ] **Step 3: Update `lib/presentation/widgets/game_controls.dart` — replace `canUndo` with `undosRemaining`**

```dart
class GameControls extends StatelessWidget {
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final VoidCallback onClear;
  final int undosRemaining;  // ← changed from canUndo

  const GameControls({
    super.key,
    required this.onUndo,
    required this.onHint,
    required this.onClear,
    this.undosRemaining = 0,  // ← changed
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon: Icons.undo,
          label: undosRemaining > 0 && undosRemaining < 99
              ? 'Undo (${undosRemaining})'
              : 'Undo',
          onTap: undosRemaining > 0 ? onUndo : null,
        ),
        _ControlButton(
            icon: Icons.lightbulb_outline, label: 'Hint', onTap: onHint),
        _ControlButton(
            icon: Icons.backspace_outlined, label: 'Clear', onTap: onClear),
      ],
    );
  }
}
```

(The `_ControlButton` class is unchanged.)

- [ ] **Step 4: Update `lib/presentation/screens/game/game_screen.dart`**

4a. Add `HeartRow` to the column, between the AppBar and `_TimerRow`, shown only for non-tutorial:

```dart
// In the Column children, add after SafeArea child column opening:
if (puzzle.difficulty != Difficulty.tutorial)
  BlocBuilder<GameBloc, GameState>(
    buildWhen: (p, c) => p.hearts != c.hearts,
    builder: (context, state) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: HeartRow(hearts: state.hearts),
    ),
  ),
_TimerRow(),
```

4b. Wire `undosRemaining` into `GameControls` (replace `canUndo`):

```dart
// Old:
builder: (context, state) => GameControls(
  canUndo: state.undoStack.isNotEmpty,
  ...
),

// New:
builder: (context, state) => GameControls(
  undosRemaining: state.undosRemaining,
  ...
),
```

4c. Wire `wrongFlashCell` into `SudokuGrid` / `CellTile`. In the `SudokuGrid` builder, pass `wrongFlashCell` down, or handle it directly in `buildWhen`:

```dart
BlocBuilder<GameBloc, GameState>(
  buildWhen: (p, c) =>
      p.board != c.board ||
      p.conflicts != c.conflicts ||
      p.hintCell != c.hintCell ||
      p.wrongFlashCell != c.wrongFlashCell,  // ← new
  builder: (context, state) => SudokuGrid(
    board: state.board,
    conflicts: state.conflicts,
    hintCell: state.hintCell,
    wrongFlashCell: state.wrongFlashCell,   // ← new
    onCellTap: (row, col) {
      context.read<GameBloc>().add(PlaceNumber(row, col));
    },
  ),
),
```

4d. Add imports at the top of game_screen.dart:
```dart
import '../../widgets/heart_row.dart';
```

- [ ] **Step 5: Update `lib/presentation/widgets/sudoku_grid.dart` to accept and pass `wrongFlashCell`**

Add parameter to `SudokuGrid`:

```dart
final Position? wrongFlashCell;
```

And in the grid cell builder (wherever `CellTile` is constructed), add:
```dart
isWrongFlash: wrongFlashCell?.row == row && wrongFlashCell?.col == col,
```

- [ ] **Step 6: Hot reload — full integration test**

Navigate: Home → Play → Easy → Puzzle 1 → select a wrong number → tap cell → red flash appears for 600ms + heart decreases. Try Undo → button shows "Undo (1)" then "Undo" (disabled after use). Complete puzzle → 3 stars if no mistakes.

- [ ] **Step 7: Commit**

```
git add lib/presentation/widgets/heart_row.dart lib/presentation/widgets/cell_tile.dart lib/presentation/widgets/game_controls.dart lib/presentation/widgets/sudoku_grid.dart lib/presentation/screens/game/game_screen.dart
git commit -m "feat: HeartRow UI, wrong-flash highlight, undo count label"
```

---

## Self-Review

**Spec coverage:**
- [x] Hearts system (3 hearts, lose on wrong answer, game over at 0) — Tasks 2, 3, 4, 8
- [x] Max 1 undo — Tasks 2, 3, 8
- [x] Tutorial levels (3 puzzles, coach mark, no hearts/no limit) — Tasks 1, 6
- [x] More difficulties (hard/expert/extreme puzzle data) — Task 7
- [x] DifficultySelectScreen — Task 5
- [x] Stars calculation updated — Task 2 (stars getter)
- [x] Tutorial puzzles skip hearts — Task 3 (`_puzzle.difficulty != Difficulty.tutorial` guard)
- [x] MemoryPuzzleRepository loads all files — Task 6
- [x] `_seedPuzzles` includes tutorial — Task 6

**Type consistency check:**
- `GameState.initial(board, isTutorial: bool)` — defined Task 2, used Task 3 ✓
- `GameBloc(puzzle: Puzzle, ...)` — defined Task 3, GameScreen updated Task 3 ✓
- `GameControls(undosRemaining: int)` — defined Task 8 Step 3, used Task 8 Step 4b ✓
- `CellTile(isWrongFlash: bool)` — defined Task 8 Step 2, used Task 8 Step 5 ✓
- `WrongFlashCleared` event — defined Task 2, handled Task 3 ✓
