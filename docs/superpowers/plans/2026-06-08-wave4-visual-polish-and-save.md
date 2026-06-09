# Wave 4: Visual Polish + Progress Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add single-slot progress auto-save/resume and 5 colour themes with dual audio-volume sliders.

**Architecture:** Progress save uses the existing Drift `Progresses` table (schema v3 adds missing columns). A new `ProgressSnapshot` domain model replaces `PuzzleProgress`. Visual settings (themes + volumes) extend `SettingsBloc`/`AudioService`; a new `SettingsScreen` consolidates all settings. `ProgressRepository` is injected via `MultiRepositoryProvider` so `GameScreen`, `HomeScreen`, and `DifficultySelectScreen` can all read it.

**Tech Stack:** Flutter/Dart, flutter_bloc, Drift (SQLite), SharedPreferences, audioplayers, google_fonts

---

## File Map

| Action | File |
|--------|------|
| Modify | `lib/domain/models/board.dart` |
| Create | `lib/domain/models/progress_snapshot.dart` |
| Replace | `lib/domain/repositories/progress_repository.dart` |
| Modify | `lib/data/local/database/app_database.dart` |
| Replace | `lib/data/repositories/local_progress_repository.dart` |
| Replace | `lib/data/repositories/memory_progress_repository.dart` |
| Modify | `lib/presentation/bloc/game/game_event.dart` |
| Modify | `lib/presentation/bloc/game/game_bloc.dart` |
| Modify | `lib/presentation/screens/game/game_screen.dart` |
| Modify | `lib/presentation/screens/home/home_screen.dart` |
| Modify | `lib/presentation/screens/difficulty_select/difficulty_select_screen.dart` |
| Modify | `lib/core/services/audio_service.dart` |
| Modify | `lib/data/local/prefs/preferences_service.dart` |
| Modify | `lib/presentation/bloc/settings/settings_state.dart` |
| Modify | `lib/presentation/bloc/settings/settings_event.dart` |
| Modify | `lib/presentation/bloc/settings/settings_bloc.dart` |
| Modify | `lib/core/theme/app_theme.dart` |
| Create | `lib/presentation/screens/settings/settings_screen.dart` |
| Modify | `lib/main.dart` |
| Modify | `test/domain/models/board_test.dart` |
| Create | `test/data/repositories/local_progress_repository_test.dart` |
| Create | `test/data/repositories/memory_progress_repository_test.dart` |
| Create | `test/presentation/bloc/settings_bloc_volume_test.dart` |

---

## Task 1: Board JSON serialization

**Files:**
- Modify: `lib/domain/models/board.dart`
- Modify: `test/domain/models/board_test.dart`

Board needs `toJson(notes)` / `fromJson(json)` for progress snapshots. Notes use `Position` keys serialised as `"row,col"` strings.

- [ ] **Step 1: Write failing tests**

Add to `test/domain/models/board_test.dart`:

```dart
import 'package:gravity_sudoku/core/utils/position.dart';

// inside main(), add a new group:
group('Board JSON serialization', () {
  test('round-trips a board with fixed cells, ice blocks, and notes', () {
    final board = Board(size: 2, cells: [
      [const Cell(value: 1, isFixed: true), const Cell()],
      [const Cell(isIceBlock: true), Cell(value: 2)],
    ]);
    final notes = {const Position(0, 1): {3, 5}};

    final json = board.toJson(notes);
    final result = Board.fromJson(json);

    expect(result.board.size, 2);
    expect(result.board.cellAt(0, 0).value, 1);
    expect(result.board.cellAt(0, 0).isFixed, isTrue);
    expect(result.board.cellAt(1, 0).isIceBlock, isTrue);
    expect(result.board.cellAt(1, 1).value, 2);
    expect(result.notes[const Position(0, 1)], containsAll([3, 5]));
    expect(result.notes.length, 1);
  });

  test('round-trips a board with empty notes', () {
    final board = Board(size: 2, cells: [
      [const Cell(value: 1), const Cell()],
      [const Cell(), const Cell(value: 2)],
    ]);

    final json = board.toJson({});
    final result = Board.fromJson(json);

    expect(result.notes, isEmpty);
    expect(result.board.cellAt(0, 0).value, 1);
  });
});
```

- [ ] **Step 2: Run tests to confirm failure**

```
D:\flutter\bin\flutter.bat test test/domain/models/board_test.dart --no-pub
```

Expected: FAIL — `The method 'toJson' isn't defined`

- [ ] **Step 3: Implement Board serialization**

Add to `lib/domain/models/board.dart` (add imports at top):

```dart
import 'dart:convert';
import '../core/utils/position.dart';
```

Then add these two methods to the `Board` class:

```dart
  String toJson(Map<Position, Set<int>> notes) {
    final cellsJson = cells
        .map((row) => row
            .map((c) => {'v': c.value, 'f': c.isFixed, 'i': c.isIceBlock})
            .toList())
        .toList();
    final notesJson = <String, List<int>>{};
    for (final entry in notes.entries) {
      notesJson['${entry.key.row},${entry.key.col}'] =
          entry.value.toList()..sort();
    }
    return jsonEncode({'size': size, 'cells': cellsJson, 'notes': notesJson});
  }

  static ({Board board, Map<Position, Set<int>> notes}) fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final size = map['size'] as int;
    final cells = (map['cells'] as List)
        .map((row) => (row as List)
            .map((c) {
              final m = c as Map<String, dynamic>;
              return Cell(
                value: m['v'] as int?,
                isFixed: (m['f'] as bool?) ?? false,
                isIceBlock: (m['i'] as bool?) ?? false,
              );
            })
            .toList())
        .toList();
    final notesMap = <Position, Set<int>>{};
    final rawNotes = (map['notes'] as Map<String, dynamic>?) ?? {};
    for (final entry in rawNotes.entries) {
      final parts = entry.key.split(',');
      notesMap[Position(int.parse(parts[0]), int.parse(parts[1]))] =
          (entry.value as List).map((v) => v as int).toSet();
    }
    return (board: Board(size: size, cells: cells), notes: notesMap);
  }
```

- [ ] **Step 4: Run tests**

```
D:\flutter\bin\flutter.bat test test/domain/models/board_test.dart --no-pub
```

Expected: All board tests pass.

- [ ] **Step 5: Run full suite**

```
D:\flutter\bin\flutter.bat test --no-pub
```

Expected: 80 tests pass (no regressions).

- [ ] **Step 6: Commit**

```
git add lib/domain/models/board.dart test/domain/models/board_test.dart
git commit -m "feat: add Board.toJson/fromJson with notes serialization"
```

---

## Task 2: ProgressSnapshot model + new ProgressRepository interface

**Files:**
- Create: `lib/domain/models/progress_snapshot.dart`
- Replace: `lib/domain/repositories/progress_repository.dart`

The old interface (`load(puzzleId)`, `save(PuzzleProgress)`, `markComplete`) is replaced. New interface: single-slot (`save(snapshot)`, `load()`, `clear()`). No tests needed for the interface itself (tested through repositories).

- [ ] **Step 1: Create `lib/domain/models/progress_snapshot.dart`**

```dart
import '../../../lib/domain/models/board.dart';
import '../../../lib/domain/models/puzzle.dart';
import '../../../lib/core/utils/position.dart';
```

Wait — use package-relative imports like the rest of the project:

```dart
import 'board.dart';
import 'puzzle.dart';
import '../../core/utils/position.dart';

class ProgressSnapshot {
  final int puzzleId;
  final Difficulty difficulty;
  final Board board;
  final Map<Position, Set<int>> notes;
  final int elapsedSeconds;
  final int hearts;
  final int undosRemaining;
  final bool isInfiniteMode;
  final int hintUsedCount;
  final DateTime savedAt;

  const ProgressSnapshot({
    required this.puzzleId,
    required this.difficulty,
    required this.board,
    required this.notes,
    required this.elapsedSeconds,
    required this.hearts,
    required this.undosRemaining,
    required this.isInfiniteMode,
    required this.hintUsedCount,
    required this.savedAt,
  });
}
```

- [ ] **Step 2: Replace `lib/domain/repositories/progress_repository.dart`**

```dart
import '../models/progress_snapshot.dart';

abstract class ProgressRepository {
  Future<void> save(ProgressSnapshot snapshot);
  Future<ProgressSnapshot?> load();
  Future<void> clear();
}
```

- [ ] **Step 3: Verify compilation**

```
D:\flutter\bin\flutter.bat analyze lib/domain/ --no-pub 2>&1 | Select-String -Pattern "error"
```

Expected: No errors in `lib/domain/`.

(Note: `lib/data/repositories/local_progress_repository.dart` and `memory_progress_repository.dart` will have errors — fixed in Tasks 3 and 4.)

- [ ] **Step 4: Commit**

```
git add lib/domain/models/progress_snapshot.dart lib/domain/repositories/progress_repository.dart
git commit -m "feat: add ProgressSnapshot model and replace ProgressRepository interface"
```

---

## Task 3: Schema v3 migration + LocalProgressRepository rewrite

**Files:**
- Modify: `lib/data/local/database/app_database.dart`
- Replace: `lib/data/repositories/local_progress_repository.dart`
- Create: `test/data/repositories/local_progress_repository_test.dart`

Schema v3 adds 5 columns to `Progresses`. Re-run code generation after schema change.

- [ ] **Step 1: Write failing test**

Create `test/data/repositories/local_progress_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/core/utils/position.dart';
import 'package:gravity_sudoku/data/local/database/app_database.dart';
import 'package:gravity_sudoku/data/repositories/local_progress_repository.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';
import 'package:gravity_sudoku/domain/models/progress_snapshot.dart';
import 'package:gravity_sudoku/domain/models/puzzle.dart';

late AppDatabase _db;
late LocalProgressRepository _repo;

Board _board2x2() => Board(size: 2, cells: [
      [const Cell(value: 1, isFixed: true), const Cell()],
      [const Cell(isIceBlock: true), Cell(value: 2)],
    ]);

ProgressSnapshot _snap({int puzzleId = 42}) => ProgressSnapshot(
      puzzleId: puzzleId,
      difficulty: Difficulty.normal,
      board: _board2x2(),
      notes: {const Position(0, 1): {3, 5}},
      elapsedSeconds: 120,
      hearts: 2,
      undosRemaining: 1,
      isInfiniteMode: false,
      hintUsedCount: 1,
      savedAt: DateTime(2026, 6, 8, 12, 0),
    );

void main() {
  setUp(() {
    _db = AppDatabase.forTesting(NativeDatabase.memory());
    _repo = LocalProgressRepository(_db);
  });

  tearDown(() async => _db.close());

  group('LocalProgressRepository', () {
    test('load returns null when empty', () async {
      expect(await _repo.load(), isNull);
    });

    test('save and load round-trips snapshot', () async {
      await _repo.save(_snap());
      final result = await _repo.load();

      expect(result, isNotNull);
      expect(result!.puzzleId, 42);
      expect(result.difficulty, Difficulty.normal);
      expect(result.elapsedSeconds, 120);
      expect(result.hearts, 2);
      expect(result.undosRemaining, 1);
      expect(result.isInfiniteMode, isFalse);
      expect(result.hintUsedCount, 1);
      expect(result.board.cellAt(0, 0).value, 1);
      expect(result.board.cellAt(0, 0).isFixed, isTrue);
      expect(result.board.cellAt(1, 0).isIceBlock, isTrue);
      expect(result.notes[const Position(0, 1)], containsAll([3, 5]));
    });

    test('save overwrites previous snapshot (single slot)', () async {
      await _repo.save(_snap(puzzleId: 1));
      await _repo.save(_snap(puzzleId: 2));
      final result = await _repo.load();
      expect(result!.puzzleId, 2);
    });

    test('clear removes snapshot', () async {
      await _repo.save(_snap());
      await _repo.clear();
      expect(await _repo.load(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm failure**

```
D:\flutter\bin\flutter.bat test test/data/repositories/local_progress_repository_test.dart --no-pub
```

Expected: FAIL — compile errors (old interface).

- [ ] **Step 3: Add 5 new columns to `Progresses` in `lib/data/local/database/app_database.dart`**

Replace the entire `Progresses` class:

```dart
class Progresses extends Table {
  IntColumn get puzzleId => integer()();
  TextColumn get boardJson => text()();
  TextColumn get undoStackJson => text()();
  IntColumn get elapsedSeconds => integer()();
  IntColumn get hintUsedCount => integer()();
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();
  // Added in schema v3:
  TextColumn get difficulty =>
      text().withDefault(const Constant('easy'))();
  IntColumn get hearts => integer().withDefault(const Constant(3))();
  BoolColumn get isInfiniteMode =>
      boolean().withDefault(const Constant(false))();
  IntColumn get undosRemaining =>
      integer().withDefault(const Constant(1))();
  IntColumn get savedAt => integer().withDefault(const Constant(0))();
}
```

Update `schemaVersion` and migration in the same file:

```dart
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(gameRecords);
      if (from < 3) {
        await m.addColumn(progresses, progresses.difficulty);
        await m.addColumn(progresses, progresses.hearts);
        await m.addColumn(progresses, progresses.isInfiniteMode);
        await m.addColumn(progresses, progresses.undosRemaining);
        await m.addColumn(progresses, progresses.savedAt);
      }
    },
  );
```

- [ ] **Step 4: Re-run code generation**

```
cd D:\projects\gravity-sudoku
D:\flutter\bin\flutter.bat pub run build_runner build --delete-conflicting-outputs
```

Expected: `app_database.g.dart` regenerated without errors.

- [ ] **Step 5: Rewrite `lib/data/repositories/local_progress_repository.dart`**

```dart
import 'package:drift/drift.dart';
import '../../core/utils/position.dart';
import '../../domain/models/board.dart';
import '../../domain/models/progress_snapshot.dart';
import '../../domain/models/puzzle.dart';
import '../../domain/repositories/progress_repository.dart';
import '../local/database/app_database.dart';

class LocalProgressRepository implements ProgressRepository {
  final AppDatabase _db;
  LocalProgressRepository(this._db);

  @override
  Future<void> save(ProgressSnapshot snapshot) async {
    await _db.delete(_db.progresses).go();
    await _db.into(_db.progresses).insert(ProgressesCompanion(
      puzzleId: Value(snapshot.puzzleId),
      boardJson: Value(snapshot.board.toJson(snapshot.notes)),
      undoStackJson: const Value('[]'),
      elapsedSeconds: Value(snapshot.elapsedSeconds),
      hintUsedCount: Value(snapshot.hintUsedCount),
      isCompleted: const Value(false),
      difficulty: Value(snapshot.difficulty.name),
      hearts: Value(snapshot.hearts),
      isInfiniteMode: Value(snapshot.isInfiniteMode),
      undosRemaining: Value(snapshot.undosRemaining),
      savedAt: Value(snapshot.savedAt.millisecondsSinceEpoch),
    ));
  }

  @override
  Future<ProgressSnapshot?> load() async {
    final row = await _db.select(_db.progresses).getSingleOrNull();
    if (row == null) return null;
    final decoded = Board.fromJson(row.boardJson);
    return ProgressSnapshot(
      puzzleId: row.puzzleId,
      difficulty: Difficulty.values.byName(row.difficulty),
      board: decoded.board,
      notes: decoded.notes,
      elapsedSeconds: row.elapsedSeconds,
      hearts: row.hearts,
      undosRemaining: row.undosRemaining,
      isInfiniteMode: row.isInfiniteMode,
      hintUsedCount: row.hintUsedCount,
      savedAt: DateTime.fromMillisecondsSinceEpoch(row.savedAt),
    );
  }

  @override
  Future<void> clear() async {
    await _db.delete(_db.progresses).go();
  }
}
```

- [ ] **Step 6: Run task tests**

```
D:\flutter\bin\flutter.bat test test/data/repositories/local_progress_repository_test.dart --no-pub
```

Expected: 4 tests pass.

- [ ] **Step 7: Run full suite**

```
D:\flutter\bin\flutter.bat test --no-pub
```

Expected: compile errors only in `memory_progress_repository.dart` (fixed in Task 4). Board tests + game record tests still pass.

- [ ] **Step 8: Commit**

```
git add lib/data/local/database/app_database.dart lib/data/local/database/app_database.g.dart lib/data/repositories/local_progress_repository.dart test/data/repositories/local_progress_repository_test.dart
git commit -m "feat: schema v3 with progress snapshot columns; rewrite LocalProgressRepository"
```

---

## Task 4: MemoryProgressRepository rewrite

**Files:**
- Replace: `lib/data/repositories/memory_progress_repository.dart`
- Create: `test/data/repositories/memory_progress_repository_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/data/repositories/memory_progress_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/core/utils/position.dart';
import 'package:gravity_sudoku/data/repositories/memory_progress_repository.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';
import 'package:gravity_sudoku/domain/models/progress_snapshot.dart';
import 'package:gravity_sudoku/domain/models/puzzle.dart';

ProgressSnapshot _snap({int puzzleId = 7}) => ProgressSnapshot(
      puzzleId: puzzleId,
      difficulty: Difficulty.easy,
      board: Board(size: 2, cells: [
        [const Cell(value: 1), const Cell()],
        [const Cell(), const Cell(value: 2)],
      ]),
      notes: {const Position(0, 1): {4}},
      elapsedSeconds: 60,
      hearts: 3,
      undosRemaining: 1,
      isInfiniteMode: true,
      hintUsedCount: 0,
      savedAt: DateTime(2026, 6, 8),
    );

void main() {
  group('MemoryProgressRepository', () {
    late MemoryProgressRepository repo;
    setUp(() => repo = MemoryProgressRepository());

    test('load returns null initially', () async {
      expect(await repo.load(), isNull);
    });

    test('save and load round-trips snapshot', () async {
      await repo.save(_snap());
      final result = await repo.load();
      expect(result!.puzzleId, 7);
      expect(result.difficulty, Difficulty.easy);
      expect(result.isInfiniteMode, isTrue);
      expect(result.notes[const Position(0, 1)], contains(4));
    });

    test('save overwrites previous snapshot', () async {
      await repo.save(_snap(puzzleId: 1));
      await repo.save(_snap(puzzleId: 2));
      expect((await repo.load())!.puzzleId, 2);
    });

    test('clear sets snapshot to null', () async {
      await repo.save(_snap());
      await repo.clear();
      expect(await repo.load(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm failure**

```
D:\flutter\bin\flutter.bat test test/data/repositories/memory_progress_repository_test.dart --no-pub
```

Expected: FAIL — compile errors.

- [ ] **Step 3: Rewrite `lib/data/repositories/memory_progress_repository.dart`**

```dart
import '../../domain/models/progress_snapshot.dart';
import '../../domain/repositories/progress_repository.dart';

class MemoryProgressRepository implements ProgressRepository {
  ProgressSnapshot? _snapshot;

  @override
  Future<void> save(ProgressSnapshot snapshot) async => _snapshot = snapshot;

  @override
  Future<ProgressSnapshot?> load() async => _snapshot;

  @override
  Future<void> clear() async => _snapshot = null;
}
```

- [ ] **Step 4: Run task tests**

```
D:\flutter\bin\flutter.bat test test/data/repositories/memory_progress_repository_test.dart --no-pub
```

Expected: 4 tests pass.

- [ ] **Step 5: Run full suite**

```
D:\flutter\bin\flutter.bat test --no-pub
```

Expected: 88 tests pass (80 original + 4 local + 4 memory).

- [ ] **Step 6: Commit**

```
git add lib/data/repositories/memory_progress_repository.dart test/data/repositories/memory_progress_repository_test.dart
git commit -m "feat: rewrite MemoryProgressRepository for single-slot ProgressSnapshot"
```

---

## Task 5: GameScreen — progress save on lifecycle + quit; resume from snapshot

**Files:**
- Modify: `lib/presentation/screens/game/game_screen.dart`

`_GameViewState` gains `WidgetsBindingObserver` to auto-save on lifecycle events. The Quit button saves a snapshot instead of a `GameRecord`. `GameScreen` accepts `ProgressSnapshot? resumeFrom`; `GameBloc` is created with a starting state derived from the snapshot when non-null. No new tests are needed (covered by existing game_bloc_test).

- [ ] **Step 1: Update `lib/presentation/screens/game/game_screen.dart`**

Replace the entire file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/symbols.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/utils/position.dart';
import '../../../domain/models/board.dart';
import '../../../domain/models/progress_snapshot.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/repositories/progress_repository.dart';
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
import '../../../domain/models/game_record.dart';
import '../../../domain/repositories/game_record_repository.dart';
import '../completion/completion_screen.dart';
import '../game_over/game_over_screen.dart';

class GameScreen extends StatelessWidget {
  final Puzzle puzzle;
  final PuzzleRepository puzzleRepo;
  final bool isInfiniteMode;
  final ProgressSnapshot? resumeFrom;

  const GameScreen({
    super.key,
    required this.puzzle,
    required this.puzzleRepo,
    this.isInfiniteMode = false,
    this.resumeFrom,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = resumeFrom;
    return BlocProvider(
      create: (ctx) {
        final audio = ctx.read<AudioService>();
        if (snapshot != null) {
          return GameBloc(
            puzzle: puzzle,
            gravity: GravityEngine(),
            validator: SudokuValidator(),
            hint: HintService(
                gravity: GravityEngine(), validator: SudokuValidator()),
            audio: audio,
            resumeFrom: snapshot,
          );
        }
        return GameBloc(
          puzzle: puzzle,
          gravity: GravityEngine(),
          validator: SudokuValidator(),
          hint: HintService(
              gravity: GravityEngine(), validator: SudokuValidator()),
          audio: audio,
          isInfiniteMode: isInfiniteMode,
        );
      },
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

class _GameViewState extends State<_GameView> with WidgetsBindingObserver {
  AudioService? _audio;
  ProgressRepository? _progressRepo;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _audio = context.read<AudioService>();
      _progressRepo = context.read<ProgressRepository>();
      _audio?.startMusic();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audio?.stopMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _saveProgress();
    }
  }

  Future<void> _saveProgress() async {
    if (_progressRepo == null || !mounted) return;
    final s = context.read<GameBloc>().state;
    if (s.status == GameStatus.completed || s.status == GameStatus.gameOver) {
      return;
    }
    await _progressRepo!.save(ProgressSnapshot(
      puzzleId: widget.puzzle.id,
      difficulty: widget.puzzle.difficulty,
      board: s.board,
      notes: s.notes,
      elapsedSeconds: s.elapsedSeconds,
      hearts: s.hearts,
      undosRemaining: s.undosRemaining,
      isInfiniteMode: s.isInfiniteMode,
      hintUsedCount: s.hintUsedCount,
      savedAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameBloc, GameState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == GameStatus.completed) {
          _progressRepo?.clear();
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
          _progressRepo?.clear();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GameOverScreen(
                puzzle: widget.puzzle,
                puzzleRepo: widget.puzzleRepo,
                isInfiniteMode: state.isInfiniteMode,
                elapsedSeconds: state.elapsedSeconds,
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
                      builder: (context, state) => state.isInfiniteMode
                          ? const SizedBox.shrink()
                          : Padding(
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
                            p.permanentlyUnlocked != c.permanentlyUnlocked ||
                            p.notes != c.notes,
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
              onPressed: () async {
                await _saveProgress();
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Quit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ));
                }
              },
              child: const Text('設定'),
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

> **Note:** `SettingsScreen` is a forward reference — it will be created in Task 10. Add a stub import `import '../settings/settings_screen.dart';` to the imports. The file won't compile until Task 10, but all other tasks compile fine. Alternatively, leave the `'設定'` button import until Task 10 and only add `_progressRepo` / `WidgetsBindingObserver` changes to the existing file in this task.

**Recommended approach for this task:** Apply all changes to `game_screen.dart` EXCEPT the `'設定'` button and its import — those are added in Task 10 when `SettingsScreen` exists.

- [ ] **Step 2: Add `resumeFrom` parameter to `GameBloc` in `lib/presentation/bloc/game/game_bloc.dart`**

Add `ProgressSnapshot? resumeFrom` optional parameter to the constructor. Change the `super()` call to branch on `resumeFrom`:

```dart
// Add import at top:
import '../../../domain/models/progress_snapshot.dart';
import '../../../domain/repositories/progress_repository.dart';  // not yet needed but for future use

// Modify constructor signature:
GameBloc({
  required Puzzle puzzle,
  required GravityEngine gravity,
  required SudokuValidator validator,
  required HintService hint,
  required AudioService audio,
  bool isInfiniteMode = false,
  ProgressSnapshot? resumeFrom,
})  : _puzzle = puzzle,
      _gravity = gravity,
      _validator = validator,
      _hint = hint,
      _audio = audio,
      super(resumeFrom != null
          ? GameState(
              board: resumeFrom.board,
              initialBoard: puzzle.initialBoard,
              elapsedSeconds: resumeFrom.elapsedSeconds,
              hearts: resumeFrom.hearts,
              undosRemaining: resumeFrom.undosRemaining,
              isInfiniteMode: resumeFrom.isInfiniteMode,
              hintUsedCount: resumeFrom.hintUsedCount,
              notes: resumeFrom.notes,
            )
          : GameState.initial(
              puzzle.initialBoard,
              isTutorial: puzzle.difficulty == Difficulty.tutorial,
              isInfiniteMode: isInfiniteMode,
            )) {
```

Keep all `on<...>` registrations and `_startTimer()` call unchanged.

- [ ] **Step 3: Run full suite**

```
D:\flutter\bin\flutter.bat test --no-pub
```

Expected: 88 tests pass.

- [ ] **Step 4: Commit**

```
git add lib/presentation/screens/game/game_screen.dart lib/presentation/bloc/game/game_bloc.dart
git commit -m "feat: add progress auto-save on lifecycle and quit; support resumeFrom in GameBloc"
```

---

## Task 6: main.dart — inject ProgressRepository; HomeScreen + DifficultySelectScreen resume entry

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/presentation/screens/home/home_screen.dart`
- Modify: `lib/presentation/screens/difficulty_select/difficulty_select_screen.dart`

`ProgressRepository` is added to `MultiRepositoryProvider`. Both screens load the snapshot on init and show "繼續上局" if one exists.

- [ ] **Step 1: Add `ProgressRepository` to `MultiRepositoryProvider` in `lib/main.dart`**

Change:
```dart
return MultiRepositoryProvider(
  providers: [
    RepositoryProvider<AudioService>.value(value: audioService),
    RepositoryProvider<GameRecordRepository>.value(value: gameRecordRepo),
  ],
```

To:
```dart
return MultiRepositoryProvider(
  providers: [
    RepositoryProvider<AudioService>.value(value: audioService),
    RepositoryProvider<GameRecordRepository>.value(value: gameRecordRepo),
    RepositoryProvider<ProgressRepository>.value(value: progressRepo),
  ],
```

- [ ] **Step 2: Update `lib/presentation/screens/home/home_screen.dart`**

Add import and two new fields to `_HomeScreenState`:

```dart
import '../../../domain/models/progress_snapshot.dart';
import '../../../domain/repositories/progress_repository.dart';
```

Add fields:
```dart
bool _resumeChecked = false;
ProgressSnapshot? _resumeSnapshot;
```

Extend `didChangeDependencies()` with a second guard:
```dart
if (!_resumeChecked) {
  _resumeChecked = true;
  context.read<ProgressRepository>().load().then((snap) {
    if (mounted) setState(() => _resumeSnapshot = snap);
  });
}
```

Add `_resumeGame()` method:
```dart
Future<void> _resumeGame(BuildContext context) async {
  final snap = _resumeSnapshot!;
  final puzzle = await widget.puzzleRepo.fetchById(snap.puzzleId);
  if (puzzle == null || !context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => GameScreen(
      puzzle: puzzle,
      puzzleRepo: widget.puzzleRepo,
      resumeFrom: snap,
    ),
  ));
}
```

Add difficulty label helper:
```dart
String _difficultyLabel(Difficulty d) {
  switch (d) {
    case Difficulty.easy:    return 'Easy';
    case Difficulty.normal:  return 'Normal';
    case Difficulty.hard:    return 'Hard';
    case Difficulty.expert:  return 'Expert';
    case Difficulty.extreme: return 'Extreme';
    case Difficulty.daily:   return 'Daily';
    default:                 return d.name;
  }
}
```

In `build()`, add the resume button after the Daily Challenge button:
```dart
if (_resumeSnapshot != null)
  TextButton(
    onPressed: () => _resumeGame(context),
    child: Text('繼續上局 · ${_difficultyLabel(_resumeSnapshot!.difficulty)}'),
  ),
```

- [ ] **Step 3: Update `lib/presentation/screens/difficulty_select/difficulty_select_screen.dart`**

Convert to handle resume. Add imports:
```dart
import '../../../domain/models/progress_snapshot.dart';
import '../../../domain/repositories/progress_repository.dart';
import '../game/game_screen.dart';  // already imported
```

Add field to `_DifficultySelectScreenState`:
```dart
bool _resumeChecked = false;
ProgressSnapshot? _resumeSnapshot;
```

Add `didChangeDependencies()`:
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (!_resumeChecked) {
    _resumeChecked = true;
    context.read<ProgressRepository>().load().then((snap) {
      if (mounted) setState(() => _resumeSnapshot = snap);
    });
  }
}
```

Add `_resumeGame()` method:
```dart
Future<void> _resumeGame(BuildContext context) async {
  final snap = _resumeSnapshot!;
  final puzzle = await widget.puzzleRepo.fetchById(snap.puzzleId);
  if (puzzle == null || !context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => GameScreen(
      puzzle: puzzle,
      puzzleRepo: widget.puzzleRepo,
      resumeFrom: snap,
    ),
  ));
}
```

Add difficulty label helper (same as HomeScreen):
```dart
String _difficultyLabel(Difficulty d) {
  switch (d) {
    case Difficulty.easy:    return 'Easy';
    case Difficulty.normal:  return 'Normal';
    case Difficulty.hard:    return 'Hard';
    case Difficulty.expert:  return 'Expert';
    case Difficulty.extreme: return 'Extreme';
    case Difficulty.daily:   return 'Daily';
    default:                 return d.name;
  }
}
```

In `build()`, add a resume card before the `Expanded(child: ListView...)` widget, inside the `Column`:
```dart
if (_resumeSnapshot != null)
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _resumeGame(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.play_circle_outline,
                  color: AppColors.primary, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('繼續上局',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    _difficultyLabel(_resumeSnapshot!.difficulty),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
```

- [ ] **Step 4: Run full suite**

```
D:\flutter\bin\flutter.bat test --no-pub
```

Expected: 88 tests pass.

- [ ] **Step 5: Commit**

```
git add lib/main.dart lib/presentation/screens/home/home_screen.dart lib/presentation/screens/difficulty_select/difficulty_select_screen.dart
git commit -m "feat: inject ProgressRepository; add resume entry in HomeScreen and DifficultySelectScreen"
```

---

## Task 7: AudioService volume + PreferencesService + SettingsBloc

**Files:**
- Modify: `lib/core/services/audio_service.dart`
- Modify: `lib/data/local/prefs/preferences_service.dart`
- Modify: `lib/presentation/bloc/settings/settings_state.dart`
- Modify: `lib/presentation/bloc/settings/settings_event.dart`
- Modify: `lib/presentation/bloc/settings/settings_bloc.dart`
- Create: `test/presentation/bloc/settings_bloc_volume_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/presentation/bloc/settings_bloc_volume_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/core/services/audio_service.dart';
import 'package:gravity_sudoku/data/local/prefs/preferences_service.dart';
import 'package:gravity_sudoku/presentation/bloc/settings/settings_bloc.dart';
import 'package:gravity_sudoku/presentation/bloc/settings/settings_event.dart';
import 'package:gravity_sudoku/presentation/bloc/settings/settings_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsBloc volume', () {
    late SettingsBloc bloc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PreferencesService(await SharedPreferences.getInstance());
      bloc = SettingsBloc(prefs, AudioService());
    });

    tearDown(() => bloc.close());

    test('initial musicVolume is 0.8', () {
      expect(bloc.state.musicVolume, closeTo(0.8, 0.001));
    });

    test('initial sfxVolume is 1.0', () {
      expect(bloc.state.sfxVolume, closeTo(1.0, 0.001));
    });

    test('ChangeMusicVolume updates state', () async {
      bloc.add(const ChangeMusicVolume(0.5));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.musicVolume, closeTo(0.5, 0.001));
    });

    test('ChangeSfxVolume updates state', () async {
      bloc.add(const ChangeSfxVolume(0.3));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.sfxVolume, closeTo(0.3, 0.001));
    });
  });
}
```

- [ ] **Step 2: Run test to confirm failure**

```
D:\flutter\bin\flutter.bat test test/presentation/bloc/settings_bloc_volume_test.dart --no-pub
```

Expected: FAIL — `ChangeMusicVolume` undefined.

- [ ] **Step 3: Update `lib/core/services/audio_service.dart`**

Add fields and methods:

```dart
class AudioService {
  AudioPlayer? _sfx;
  AudioPlayer? _music;
  bool _sfxEnabled = true;
  bool _musicEnabled = true;
  double _musicVolume = 0.8;
  double _sfxVolume = 1.0;

  // ... existing getters unchanged ...

  Future<void> _playSfx(String asset) async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.setVolume(_sfxVolume);
      await _sfxPlayer.play(AssetSource(asset));
    } catch (_) {}
  }

  Future<void> startMusic() async {
    if (!_musicEnabled) return;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_musicVolume);
      await _musicPlayer.play(AssetSource('audio/bg_music.wav'));
    } catch (_) {}
  }

  // ... stopMusic unchanged ...

  void setSfxEnabled(bool v) {
    _sfxEnabled = v;
    if (!v) _sfx?.stop();
  }

  void setMusicEnabled(bool v) {
    _musicEnabled = v;
    if (!v) {
      _music?.stop();
    } else {
      startMusic();
    }
  }

  void setMusicVolume(double v) {
    _musicVolume = v.clamp(0.0, 1.0);
    _music?.setVolume(_musicVolume);
  }

  void setSfxVolume(double v) {
    _sfxVolume = v.clamp(0.0, 1.0);
  }

  // ... dispose unchanged ...
}
```

- [ ] **Step 4: Update `lib/data/local/prefs/preferences_service.dart`**

Add to the class:

```dart
static const _musicVolumeKey = 'music_volume';
static const _sfxVolumeKey = 'sfx_volume';

double get musicVolume => _prefs.getDouble(_musicVolumeKey) ?? 0.8;
double get sfxVolume => _prefs.getDouble(_sfxVolumeKey) ?? 1.0;

Future<void> setMusicVolume(double v) =>
    _prefs.setDouble(_musicVolumeKey, v);
Future<void> setSfxVolume(double v) =>
    _prefs.setDouble(_sfxVolumeKey, v);
```

- [ ] **Step 5: Update `lib/presentation/bloc/settings/settings_state.dart`**

Add two fields:

```dart
class SettingsState extends Equatable {
  final bool sfxEnabled;
  final bool musicEnabled;
  final String theme;
  final double musicVolume;
  final double sfxVolume;

  const SettingsState({
    this.sfxEnabled = true,
    this.musicEnabled = true,
    this.theme = 'light',
    this.musicVolume = 0.8,
    this.sfxVolume = 1.0,
  });

  SettingsState copyWith({
    bool? sfxEnabled,
    bool? musicEnabled,
    String? theme,
    double? musicVolume,
    double? sfxVolume,
  }) =>
      SettingsState(
        sfxEnabled: sfxEnabled ?? this.sfxEnabled,
        musicEnabled: musicEnabled ?? this.musicEnabled,
        theme: theme ?? this.theme,
        musicVolume: musicVolume ?? this.musicVolume,
        sfxVolume: sfxVolume ?? this.sfxVolume,
      );

  @override
  List<Object> get props =>
      [sfxEnabled, musicEnabled, theme, musicVolume, sfxVolume];
}
```

- [ ] **Step 6: Update `lib/presentation/bloc/settings/settings_event.dart`**

Add two events:

```dart
class ChangeMusicVolume extends SettingsEvent {
  final double volume;
  const ChangeMusicVolume(this.volume);
}

class ChangeSfxVolume extends SettingsEvent {
  final double volume;
  const ChangeSfxVolume(this.volume);
}
```

- [ ] **Step 7: Update `lib/presentation/bloc/settings/settings_bloc.dart`**

Extend constructor to load volumes and register two new handlers:

```dart
SettingsBloc(this._prefs, this._audio)
    : super(SettingsState(
        sfxEnabled: _prefs.sfxEnabled,
        musicEnabled: _prefs.musicEnabled,
        theme: _prefs.selectedTheme,
        musicVolume: _prefs.musicVolume,
        sfxVolume: _prefs.sfxVolume,
      )) {
  on<ToggleSfx>(...);    // unchanged
  on<ToggleMusic>(...);  // unchanged
  on<ChangeTheme>(...);  // unchanged
  on<ChangeMusicVolume>((e, emit) async {
    final v = e.volume.clamp(0.0, 1.0);
    await _prefs.setMusicVolume(v);
    _audio.setMusicVolume(v);
    emit(state.copyWith(musicVolume: v));
  });
  on<ChangeSfxVolume>((e, emit) async {
    final v = e.volume.clamp(0.0, 1.0);
    await _prefs.setSfxVolume(v);
    _audio.setSfxVolume(v);
    emit(state.copyWith(sfxVolume: v));
  });
}
```

- [ ] **Step 8: Run task tests**

```
D:\flutter\bin\flutter.bat test test/presentation/bloc/settings_bloc_volume_test.dart --no-pub
```

Expected: 4 tests pass.

- [ ] **Step 9: Run full suite**

```
D:\flutter\bin\flutter.bat test --no-pub
```

Expected: 92 tests pass.

- [ ] **Step 10: Commit**

```
git add lib/core/services/audio_service.dart lib/data/local/prefs/preferences_service.dart lib/presentation/bloc/settings/settings_state.dart lib/presentation/bloc/settings/settings_event.dart lib/presentation/bloc/settings/settings_bloc.dart test/presentation/bloc/settings_bloc_volume_test.dart
git commit -m "feat: add music/SFX volume controls to AudioService, PreferencesService, and SettingsBloc"
```

---

## Task 8: AppTheme — 3 new themes + `forName()`

**Files:**
- Modify: `lib/core/theme/app_theme.dart`

No tests needed (ThemeData construction has no logic to test).

- [ ] **Step 1: Update `lib/core/theme/app_theme.dart`**

Replace file content:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData forName(String name) {
    switch (name) {
      case 'dark':
        return dark();
      case 'ocean':
        return ocean();
      case 'sunset':
        return sunset();
      case 'forest':
        return forest();
      default:
        return light();
    }
  }

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.nunitoTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.text,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: AppColors.primary,
          surface: AppColors.darkSurface,
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
        textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBackground,
          elevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.darkText,
        ),
      );

  static ThemeData ocean() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF1565C0),
          surface: const Color(0xFF0D2137),
        ),
        scaffoldBackgroundColor: const Color(0xFF071828),
        textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF071828),
          elevation: 0,
          centerTitle: true,
          foregroundColor: Color(0xFFB3E5FC),
        ),
      );

  static ThemeData sunset() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE65100),
          surface: const Color(0xFFFFF3E0),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8F0),
        textTheme: GoogleFonts.nunitoTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF8F0),
          elevation: 0,
          centerTitle: true,
          foregroundColor: Color(0xFF4E2000),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE65100),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  static ThemeData forest() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF1B5E20),
          surface: const Color(0xFF0D2110),
        ),
        scaffoldBackgroundColor: const Color(0xFF071209),
        textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF071209),
          elevation: 0,
          centerTitle: true,
          foregroundColor: Color(0xFFA5D6A7),
        ),
      );
}
```

- [ ] **Step 2: Run full suite**

```
D:\flutter\bin\flutter.bat test --no-pub
```

Expected: 92 tests pass.

- [ ] **Step 3: Commit**

```
git add lib/core/theme/app_theme.dart
git commit -m "feat: add ocean/sunset/forest themes and AppTheme.forName()"
```

---

## Task 9: SettingsScreen + HomeScreen settings icon + PauseMenu settings button + main.dart theme switch

**Files:**
- Create: `lib/presentation/screens/settings/settings_screen.dart`
- Modify: `lib/presentation/screens/home/home_screen.dart`
- Modify: `lib/presentation/screens/game/game_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create `lib/presentation/screens/settings/settings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../presentation/bloc/settings/settings_bloc.dart';
import '../../../presentation/bloc/settings/settings_event.dart';
import '../../../presentation/bloc/settings/settings_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _themes = [
    ('light', 'Light'),
    ('dark', 'Dark'),
    ('ocean', 'Ocean'),
    ('sunset', 'Sunset'),
    ('forest', 'Forest'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settings) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('主題',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _themes
                  .map((t) => ChoiceChip(
                        label: Text(t.$2),
                        selected: settings.theme == t.$1,
                        onSelected: (_) => context
                            .read<SettingsBloc>()
                            .add(ChangeTheme(t.$1)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 28),
            const Text('音樂音量',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Slider(
              value: settings.musicVolume,
              min: 0,
              max: 1,
              divisions: 10,
              label: '${(settings.musicVolume * 100).round()}%',
              onChanged: (v) =>
                  context.read<SettingsBloc>().add(ChangeMusicVolume(v)),
            ),
            const SizedBox(height: 16),
            const Text('音效音量',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Slider(
              value: settings.sfxVolume,
              min: 0,
              max: 1,
              divisions: 10,
              label: '${(settings.sfxVolume * 100).round()}%',
              onChanged: (v) =>
                  context.read<SettingsBloc>().add(ChangeSfxVolume(v)),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update HomeScreen — replace sun/moon toggle with settings icon**

In `lib/presentation/screens/home/home_screen.dart`, change the `AppBar.actions`:

```dart
// Old:
actions: [
  IconButton(
    icon: Icon(
      settings.theme == 'dark'
          ? Icons.light_mode_outlined
          : Icons.dark_mode_outlined,
    ),
    onPressed: () => context.read<SettingsBloc>().add(
          ChangeTheme(settings.theme == 'dark' ? 'light' : 'dark'),
        ),
  ),
],

// New:
actions: [
  IconButton(
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    ),
  ),
],
```

Also remove the `BlocBuilder<SettingsBloc, SettingsState>` wrapping if it was only there for the theme toggle. The `BlocBuilder` in `HomeScreen.build()` wraps the entire Scaffold — it is no longer needed for HomeScreen itself. Simplify `build()` to remove the outer `BlocBuilder`:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    ),
    body: SafeArea(
      // ... rest of body unchanged ...
    ),
  );
}
```

Add import for `SettingsScreen`:
```dart
import '../settings/settings_screen.dart';
```

Remove unused imports `settings_event.dart` and `settings_state.dart` from HomeScreen if they're no longer referenced.

- [ ] **Step 3: Add `'設定'` button to pause menu in `lib/presentation/screens/game/game_screen.dart`**

In `_showPauseMenu`, add the settings button after the Quit button (this was deferred from Task 5):

```dart
TextButton(
  onPressed: () {
    Navigator.pop(context);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }
  },
  child: const Text('設定'),
),
```

Add import at top of `game_screen.dart`:
```dart
import '../settings/settings_screen.dart';
```

Also remove the `SwitchListTile('Dark mode')` — replace the `content` field of the `AlertDialog` with no `content` (or remove it):

Change:
```dart
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
```

To: (remove the `content:` parameter entirely, or leave it empty)

The `BlocBuilder<SettingsBloc, SettingsState>` wrapper in `_showPauseMenu` is also no longer needed since there's no theme toggle in the dialog — remove it and use a plain `AlertDialog`.

- [ ] **Step 4: Switch `main.dart` to `AppTheme.forName()`**

In `lib/main.dart`, change the `MaterialApp` theme configuration:

```dart
// Old:
theme: AppTheme.light(),
darkTheme: AppTheme.dark(),
themeMode:
    settings.theme == 'dark' ? ThemeMode.dark : ThemeMode.light,

// New:
theme: AppTheme.forName(settings.theme),
```

Remove the `darkTheme:` and `themeMode:` lines.

- [ ] **Step 5: Run full suite**

```
D:\flutter\bin\flutter.bat test --no-pub
```

Expected: 92 tests pass.

- [ ] **Step 6: Commit**

```
git add lib/presentation/screens/settings/settings_screen.dart lib/presentation/screens/home/home_screen.dart lib/presentation/screens/game/game_screen.dart lib/main.dart
git commit -m "feat: add SettingsScreen with theme picker and volume sliders; wire pause menu and home screen"
```

---

## Self-Review Checklist

**Spec coverage:**

| Requirement | Task |
|-------------|------|
| Auto-save on Quit | Task 5 (Quit button calls `_saveProgress()`) |
| Auto-save on `AppLifecycleState.inactive/paused` | Task 5 (`WidgetsBindingObserver`) |
| Single-slot progress | Task 3 (delete-before-insert) |
| Resume entry in HomeScreen | Task 6 |
| Resume entry in DifficultySelectScreen | Task 6 |
| Clear progress when game starts/ends | Task 5 (`_progressRepo?.clear()` on complete/gameOver) |
| `ProgressRepository` injected | Task 6 (main.dart) |
| Schema v3 migration | Task 3 |
| 5 colour themes | Task 8 |
| `AppTheme.forName()` | Task 8 |
| Remove darkTheme/themeMode | Task 9 |
| `musicVolume` / `sfxVolume` in SettingsState | Task 7 |
| `ChangeMusicVolume` / `ChangeSfxVolume` events | Task 7 |
| `AudioService.setMusicVolume` / `setSfxVolume` | Task 7 |
| SharedPreferences persistence for volumes | Task 7 |
| `SettingsScreen` with 5 ChoiceChips + 2 Sliders | Task 9 |
| HomeScreen settings icon (replaces sun/moon) | Task 9 |
| PauseMenu „設定" button | Task 9 |
| PauseMenu Dark Mode toggle removed | Task 9 |

**Missing:** Clear progress when a new game starts via DifficultySelectScreen. Add this to Task 6: in `_start()` method of `_DifficultySelectScreenState`, call `context.read<ProgressRepository>().clear()` before pushing `GameScreen`. Similarly in `HomeScreen._startDaily()`. Also in `HomeScreen` Play button (navigates to DifficultySelectScreen — clearing happens when a difficulty is chosen).

Update Task 6 to include: in `_DifficultySelectScreenState._start()`, add:

```dart
// Before nav.push(...):
await context.read<ProgressRepository>().clear();
```

And in `HomeScreen._startDaily()`, add before pushing:

```dart
await context.read<ProgressRepository>().clear();
```
