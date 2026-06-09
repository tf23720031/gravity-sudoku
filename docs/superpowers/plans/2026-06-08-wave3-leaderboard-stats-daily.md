# Wave 3: Leaderboard + Stats + Daily Challenge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `GameRecord` persistence layer and surface it as a per-difficulty local leaderboard (top 10), a statistics page, and a daily challenge that rotates through a `daily` puzzle pool by date.

**Architecture:** A single `game_records` Drift table stores every game outcome (completed and abandoned). `GameRecordRepository` is injected at the app root via `RepositoryProvider` (same pattern as `AudioService`) so any screen can call `context.read<GameRecordRepository>()`. Leaderboard and stats screens use `FutureBuilder`; no new BLoC needed.

**Tech Stack:** Flutter, flutter_bloc, Drift (SQLite), `bloc_test`, `drift/native.dart` for in-memory test DB.

---

## File Map

| File | Change |
|------|--------|
| `lib/domain/models/game_record.dart` | New — `GameRecord`, `GameStats` |
| `lib/domain/repositories/game_record_repository.dart` | New — abstract interface |
| `lib/data/local/database/app_database.dart` | + `GameRecords` table; schema 1→2; migration; `forTesting` factory |
| `lib/data/repositories/local_game_record_repository.dart` | New — Drift impl |
| `lib/data/repositories/memory_game_record_repository.dart` | New — in-memory impl |
| `lib/data/repositories/local_puzzle_repository.dart` | Implement `fetchDaily()` with date rotation |
| `lib/data/repositories/memory_puzzle_repository.dart` | Update `fetchDaily()` with date rotation |
| `assets/puzzles/daily_9x9.json` | New — daily puzzle pool |
| `lib/main.dart` | Create + inject `GameRecordRepository` via `MultiRepositoryProvider` |
| `lib/presentation/screens/completion/completion_screen.dart` | Save record on completion |
| `lib/presentation/screens/game_over/game_over_screen.dart` | + `elapsedSeconds` param; save record |
| `lib/presentation/screens/game/game_screen.dart` | Pass `elapsedSeconds` to `GameOverScreen`; Quit saves record |
| `lib/presentation/screens/leaderboard/leaderboard_screen.dart` | New |
| `lib/presentation/screens/stats/stats_screen.dart` | New |
| `lib/presentation/screens/home/home_screen.dart` | StatefulWidget; daily state; new nav buttons |
| `test/domain/models/game_record_test.dart` | New |
| `test/data/repositories/local_game_record_repository_test.dart` | New |
| `test/data/repositories/memory_game_record_repository_test.dart` | New |

---

### Task 1: GameRecord + GameStats models + GameRecordRepository interface

**Files:**
- Create: `lib/domain/models/game_record.dart`
- Create: `lib/domain/repositories/game_record_repository.dart`
- Test: `test/domain/models/game_record_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/domain/models/game_record_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/domain/models/game_record.dart';
import 'package:gravity_sudoku/domain/models/puzzle.dart';

void main() {
  group('GameRecord', () {
    test('can be constructed with all fields', () {
      final now = DateTime(2026, 6, 8, 12, 0, 0);
      final record = GameRecord(
        id: 1,
        difficulty: Difficulty.normal,
        elapsedSeconds: 120,
        stars: 3,
        isCompleted: true,
        completedAt: now,
      );
      expect(record.id, 1);
      expect(record.difficulty, Difficulty.normal);
      expect(record.elapsedSeconds, 120);
      expect(record.stars, 3);
      expect(record.isCompleted, isTrue);
      expect(record.completedAt, now);
    });

    test('isCompleted false for abandoned game', () {
      final record = GameRecord(
        id: 2,
        difficulty: Difficulty.hard,
        elapsedSeconds: 45,
        stars: 0,
        isCompleted: false,
        completedAt: DateTime.now(),
      );
      expect(record.isCompleted, isFalse);
      expect(record.stars, 0);
    });
  });

  group('GameStats', () {
    test('can be constructed', () {
      const stats = GameStats(
        gamesCompleted: 5,
        gamesPlayed: 8,
        bestSeconds: 90,
        avgStars: 2.4,
        avgSeconds: 120,
        totalSeconds: 960,
      );
      expect(stats.gamesCompleted, 5);
      expect(stats.gamesPlayed, 8);
      expect(stats.bestSeconds, 90);
      expect(stats.avgStars, closeTo(2.4, 0.001));
      expect(stats.avgSeconds, 120);
      expect(stats.totalSeconds, 960);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/domain/models/game_record_test.dart
```

Expected: FAIL — `GameRecord` and `GameStats` not defined.

- [ ] **Step 3: Create `lib/domain/models/game_record.dart`**

```dart
import 'puzzle.dart';

class GameRecord {
  final int id;
  final Difficulty difficulty;
  final int elapsedSeconds;
  final int stars;
  final bool isCompleted;
  final DateTime completedAt;

  const GameRecord({
    required this.id,
    required this.difficulty,
    required this.elapsedSeconds,
    required this.stars,
    required this.isCompleted,
    required this.completedAt,
  });
}

class GameStats {
  final int gamesCompleted;
  final int gamesPlayed;
  final int bestSeconds;    // -1 if no completions
  final double avgStars;
  final int avgSeconds;     // -1 if no completions
  final int totalSeconds;

  const GameStats({
    required this.gamesCompleted,
    required this.gamesPlayed,
    required this.bestSeconds,
    required this.avgStars,
    required this.avgSeconds,
    required this.totalSeconds,
  });
}
```

- [ ] **Step 4: Create `lib/domain/repositories/game_record_repository.dart`**

```dart
import '../models/game_record.dart';
import '../models/puzzle.dart';

abstract class GameRecordRepository {
  Future<void> insert(GameRecord record);
  Future<List<GameRecord>> topN(Difficulty difficulty, {int n = 10});
  Future<GameStats?> statsFor(Difficulty difficulty);
  Future<bool> hasCompletedDailyToday();
}
```

- [ ] **Step 5: Run test to verify it passes**

```
flutter test test/domain/models/game_record_test.dart
```

Expected: PASS (2 groups, 3 tests).

- [ ] **Step 6: Commit**

```
git add lib/domain/models/game_record.dart lib/domain/repositories/game_record_repository.dart test/domain/models/game_record_test.dart
git commit -m "feat: add GameRecord/GameStats models and GameRecordRepository interface"
```

---

### Task 2: AppDatabase — GameRecords table + schema migration + forTesting factory

**Files:**
- Modify: `lib/data/local/database/app_database.dart`

Context: `app_database.dart` already has `Puzzles` and `Progresses` tables with `schemaVersion => 1`. We add a third table, bump to schema 2, add a migration, and a `forTesting` factory for tests. After editing, run the Drift code generator to regenerate `app_database.g.dart`.

**Important:** The Drift table class is named `GameRecords`. Drift auto-generates a data class for rows named `GameRecord` — the same name as our domain model. To avoid collision, add `@DataClassName('GameRecordRow')` to the table so Drift generates `GameRecordRow` instead.

- [ ] **Step 1: Replace `lib/data/local/database/app_database.dart`**

```dart
import 'package:drift/drift.dart';
import 'database_connection.dart'
    if (dart.library.html) 'database_connection_web.dart'
    if (dart.library.io) 'database_connection_native.dart';

part 'app_database.g.dart';

class Puzzles extends Table {
  IntColumn get id => integer()();
  IntColumn get size => integer()();
  TextColumn get difficulty => text()();
  TextColumn get boardJson => text()();
  TextColumn get solutionJson => text()();
  TextColumn get iceBlocksJson => text()();
  TextColumn get fixedPositionsJson => text()();
}

class Progresses extends Table {
  IntColumn get puzzleId => integer()();
  TextColumn get boardJson => text()();
  TextColumn get undoStackJson => text()();
  IntColumn get elapsedSeconds => integer()();
  IntColumn get hintUsedCount => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}

@DataClassName('GameRecordRow')
class GameRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get difficulty => text()();
  IntColumn get elapsedSeconds => integer()();
  IntColumn get stars => integer()();
  BoolColumn get isCompleted => boolean()();
  IntColumn get completedAt => integer()();  // Unix ms
}

@DriftDatabase(tables: [Puzzles, Progresses, GameRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openDbConnection());
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(gameRecords);
    },
  );
}
```

- [ ] **Step 2: Run code generator**

```
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: Completes without errors. `lib/data/local/database/app_database.g.dart` is regenerated and now includes `GameRecords` table accessors.

- [ ] **Step 3: Run all tests to verify nothing broken**

```
flutter test
```

Expected: All existing 62 tests still pass (model + bloc tests unaffected).

- [ ] **Step 4: Commit**

```
git add lib/data/local/database/app_database.dart lib/data/local/database/app_database.g.dart
git commit -m "feat: add GameRecords Drift table; schema migration 1→2; forTesting factory"
```

---

### Task 3: LocalGameRecordRepository

**Files:**
- Create: `lib/data/repositories/local_game_record_repository.dart`
- Test: `test/data/repositories/local_game_record_repository_test.dart`

Context: Drift row type for `GameRecords` is `GameRecordRow` (set by `@DataClassName`). Domain model is `GameRecord`. Import domain model with alias `as domain` and `Puzzle` enum as `as puzzle_model` to avoid confusion. Use `NativeDatabase.memory()` (from `package:drift/native.dart`) for in-memory test DB.

- [ ] **Step 1: Write failing tests**

Create `test/data/repositories/local_game_record_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/data/local/database/app_database.dart';
import 'package:gravity_sudoku/data/repositories/local_game_record_repository.dart';
import 'package:gravity_sudoku/domain/models/game_record.dart';
import 'package:gravity_sudoku/domain/models/puzzle.dart';

late AppDatabase _db;
late LocalGameRecordRepository _repo;

void main() {
  setUp(() {
    _db = AppDatabase.forTesting(NativeDatabase.memory());
    _repo = LocalGameRecordRepository(_db);
  });

  tearDown(() async => _db.close());

  final _now = DateTime(2026, 6, 8, 10, 0, 0);

  GameRecord _record({
    Difficulty difficulty = Difficulty.normal,
    int elapsedSeconds = 120,
    int stars = 3,
    bool isCompleted = true,
    DateTime? completedAt,
  }) =>
      GameRecord(
        id: 0,
        difficulty: difficulty,
        elapsedSeconds: elapsedSeconds,
        stars: stars,
        isCompleted: isCompleted,
        completedAt: completedAt ?? _now,
      );

  group('LocalGameRecordRepository', () {
    test('insert and topN returns completed records sorted by time', () async {
      await _repo.insert(_record(elapsedSeconds: 180));
      await _repo.insert(_record(elapsedSeconds: 90));
      await _repo.insert(_record(elapsedSeconds: 240));
      final top = await _repo.topN(Difficulty.normal);
      expect(top.length, 3);
      expect(top[0].elapsedSeconds, 90);
      expect(top[1].elapsedSeconds, 180);
      expect(top[2].elapsedSeconds, 240);
    });

    test('topN excludes incomplete records', () async {
      await _repo.insert(_record(elapsedSeconds: 60));
      await _repo.insert(_record(elapsedSeconds: 30, isCompleted: false, stars: 0));
      final top = await _repo.topN(Difficulty.normal);
      expect(top.length, 1);
      expect(top[0].elapsedSeconds, 60);
    });

    test('topN respects n limit', () async {
      for (var i = 1; i <= 15; i++) {
        await _repo.insert(_record(elapsedSeconds: i * 10));
      }
      final top = await _repo.topN(Difficulty.normal, n: 10);
      expect(top.length, 10);
      expect(top[0].elapsedSeconds, 10);
    });

    test('topN only returns records for requested difficulty', () async {
      await _repo.insert(_record(difficulty: Difficulty.normal, elapsedSeconds: 100));
      await _repo.insert(_record(difficulty: Difficulty.hard, elapsedSeconds: 50));
      final top = await _repo.topN(Difficulty.normal);
      expect(top.length, 1);
      expect(top[0].elapsedSeconds, 100);
    });

    test('statsFor returns null when no records', () async {
      final stats = await _repo.statsFor(Difficulty.easy);
      expect(stats, isNull);
    });

    test('statsFor computes correct values', () async {
      await _repo.insert(_record(elapsedSeconds: 100, stars: 3));
      await _repo.insert(_record(elapsedSeconds: 200, stars: 2));
      await _repo.insert(_record(elapsedSeconds: 50, isCompleted: false, stars: 0));
      final stats = await _repo.statsFor(Difficulty.normal);
      expect(stats!.gamesCompleted, 2);
      expect(stats.gamesPlayed, 3);
      expect(stats.bestSeconds, 100);
      expect(stats.avgSeconds, 150);
      expect(stats.avgStars, closeTo(2.5, 0.001));
      expect(stats.totalSeconds, 350);
    });

    test('hasCompletedDailyToday returns false with no records', () async {
      final done = await _repo.hasCompletedDailyToday();
      expect(done, isFalse);
    });

    test('hasCompletedDailyToday returns true after daily completion today', () async {
      final today = DateTime.now();
      await _repo.insert(GameRecord(
        id: 0,
        difficulty: Difficulty.daily,
        elapsedSeconds: 300,
        stars: 2,
        isCompleted: true,
        completedAt: DateTime(today.year, today.month, today.day, 9, 0),
      ));
      final done = await _repo.hasCompletedDailyToday();
      expect(done, isTrue);
    });

    test('hasCompletedDailyToday returns false for yesterday daily', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await _repo.insert(GameRecord(
        id: 0,
        difficulty: Difficulty.daily,
        elapsedSeconds: 300,
        stars: 2,
        isCompleted: true,
        completedAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 0),
      ));
      final done = await _repo.hasCompletedDailyToday();
      expect(done, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/data/repositories/local_game_record_repository_test.dart
```

Expected: FAIL — `LocalGameRecordRepository` not found.

- [ ] **Step 3: Create `lib/data/repositories/local_game_record_repository.dart`**

```dart
import 'dart:math' as math;
import 'package:drift/drift.dart';
import '../../domain/models/game_record.dart' as domain;
import '../../domain/models/puzzle.dart' as puzzle_model;
import '../../domain/repositories/game_record_repository.dart';
import '../local/database/app_database.dart';

class LocalGameRecordRepository implements GameRecordRepository {
  final AppDatabase _db;
  LocalGameRecordRepository(this._db);

  @override
  Future<void> insert(domain.GameRecord record) async {
    await _db.into(_db.gameRecords).insert(GameRecordsCompanion(
      difficulty: Value(record.difficulty.name),
      elapsedSeconds: Value(record.elapsedSeconds),
      stars: Value(record.stars),
      isCompleted: Value(record.isCompleted),
      completedAt: Value(record.completedAt.millisecondsSinceEpoch),
    ));
  }

  @override
  Future<List<domain.GameRecord>> topN(
      puzzle_model.Difficulty difficulty, {int n = 10}) async {
    final rows = await (_db.select(_db.gameRecords)
          ..where((r) =>
              r.difficulty.equals(difficulty.name) &
              r.isCompleted.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.elapsedSeconds)])
          ..limit(n))
        .get();
    return rows.map(_toModel).toList();
  }

  @override
  Future<domain.GameStats?> statsFor(puzzle_model.Difficulty difficulty) async {
    final all = await (_db.select(_db.gameRecords)
          ..where((r) => r.difficulty.equals(difficulty.name)))
        .get();
    if (all.isEmpty) return null;
    final completed = all.where((r) => r.isCompleted).toList();
    final bestSeconds = completed.isEmpty
        ? -1
        : completed.map((r) => r.elapsedSeconds).reduce(math.min);
    final avgSeconds = completed.isEmpty
        ? -1
        : (completed.map((r) => r.elapsedSeconds).reduce((a, b) => a + b) /
                completed.length)
            .round();
    final avgStars = completed.isEmpty
        ? 0.0
        : completed.map((r) => r.stars).reduce((a, b) => a + b) /
            completed.length;
    final totalSeconds =
        all.map((r) => r.elapsedSeconds).reduce((a, b) => a + b);
    return domain.GameStats(
      gamesCompleted: completed.length,
      gamesPlayed: all.length,
      bestSeconds: bestSeconds,
      avgStars: avgStars,
      avgSeconds: avgSeconds,
      totalSeconds: totalSeconds,
    );
  }

  @override
  Future<bool> hasCompletedDailyToday() async {
    final today = DateTime.now();
    final startMs =
        DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final endMs = startMs + const Duration(days: 1).inMilliseconds;
    final rows = await (_db.select(_db.gameRecords)
          ..where((r) =>
              r.difficulty.equals(puzzle_model.Difficulty.daily.name) &
              r.isCompleted.equals(true) &
              r.completedAt.isBiggerOrEqualValue(startMs) &
              r.completedAt.isSmallerThanValue(endMs)))
        .get();
    return rows.isNotEmpty;
  }

  domain.GameRecord _toModel(GameRecordRow row) => domain.GameRecord(
        id: row.id,
        difficulty:
            puzzle_model.Difficulty.values.byName(row.difficulty),
        elapsedSeconds: row.elapsedSeconds,
        stars: row.stars,
        isCompleted: row.isCompleted,
        completedAt:
            DateTime.fromMillisecondsSinceEpoch(row.completedAt),
      );
}
```

- [ ] **Step 4: Run tests to verify they pass**

```
flutter test test/data/repositories/local_game_record_repository_test.dart
```

Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```
git add lib/data/repositories/local_game_record_repository.dart test/data/repositories/local_game_record_repository_test.dart
git commit -m "feat: add LocalGameRecordRepository with Drift"
```

---

### Task 4: MemoryGameRecordRepository

**Files:**
- Create: `lib/data/repositories/memory_game_record_repository.dart`
- Test: `test/data/repositories/memory_game_record_repository_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/data/repositories/memory_game_record_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/data/repositories/memory_game_record_repository.dart';
import 'package:gravity_sudoku/domain/models/game_record.dart';
import 'package:gravity_sudoku/domain/models/puzzle.dart';

void main() {
  late MemoryGameRecordRepository repo;

  setUp(() => repo = MemoryGameRecordRepository());

  GameRecord _record({
    Difficulty difficulty = Difficulty.normal,
    int elapsedSeconds = 120,
    int stars = 3,
    bool isCompleted = true,
    DateTime? completedAt,
  }) =>
      GameRecord(
        id: 0,
        difficulty: difficulty,
        elapsedSeconds: elapsedSeconds,
        stars: stars,
        isCompleted: isCompleted,
        completedAt: completedAt ?? DateTime(2026, 6, 8, 10, 0),
      );

  group('MemoryGameRecordRepository', () {
    test('topN returns sorted completed records', () async {
      await repo.insert(_record(elapsedSeconds: 200));
      await repo.insert(_record(elapsedSeconds: 100));
      final top = await repo.topN(Difficulty.normal);
      expect(top[0].elapsedSeconds, 100);
      expect(top[1].elapsedSeconds, 200);
    });

    test('topN excludes incomplete', () async {
      await repo.insert(_record(elapsedSeconds: 60));
      await repo.insert(_record(elapsedSeconds: 30, isCompleted: false, stars: 0));
      final top = await repo.topN(Difficulty.normal);
      expect(top.length, 1);
    });

    test('topN respects n limit', () async {
      for (var i = 0; i < 15; i++) {
        await repo.insert(_record(elapsedSeconds: i * 10 + 10));
      }
      expect((await repo.topN(Difficulty.normal, n: 10)).length, 10);
    });

    test('statsFor returns null when empty', () async {
      expect(await repo.statsFor(Difficulty.easy), isNull);
    });

    test('statsFor computes values correctly', () async {
      await repo.insert(_record(elapsedSeconds: 100, stars: 3));
      await repo.insert(_record(elapsedSeconds: 200, stars: 1));
      final stats = await repo.statsFor(Difficulty.normal);
      expect(stats!.gamesCompleted, 2);
      expect(stats.bestSeconds, 100);
      expect(stats.avgSeconds, 150);
      expect(stats.avgStars, closeTo(2.0, 0.001));
    });

    test('hasCompletedDailyToday works', () async {
      expect(await repo.hasCompletedDailyToday(), isFalse);
      final today = DateTime.now();
      await repo.insert(GameRecord(
        id: 0,
        difficulty: Difficulty.daily,
        elapsedSeconds: 200,
        stars: 2,
        isCompleted: true,
        completedAt: DateTime(today.year, today.month, today.day, 8, 0),
      ));
      expect(await repo.hasCompletedDailyToday(), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/data/repositories/memory_game_record_repository_test.dart
```

Expected: FAIL — class not found.

- [ ] **Step 3: Create `lib/data/repositories/memory_game_record_repository.dart`**

```dart
import 'dart:math' as math;
import '../../domain/models/game_record.dart';
import '../../domain/models/puzzle.dart';
import '../../domain/repositories/game_record_repository.dart';

class MemoryGameRecordRepository implements GameRecordRepository {
  final _records = <GameRecord>[];
  int _nextId = 1;

  @override
  Future<void> insert(GameRecord record) async {
    _records.add(GameRecord(
      id: _nextId++,
      difficulty: record.difficulty,
      elapsedSeconds: record.elapsedSeconds,
      stars: record.stars,
      isCompleted: record.isCompleted,
      completedAt: record.completedAt,
    ));
  }

  @override
  Future<List<GameRecord>> topN(Difficulty difficulty, {int n = 10}) async {
    final completed = _records
        .where((r) => r.difficulty == difficulty && r.isCompleted)
        .toList()
      ..sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
    return completed.take(n).toList();
  }

  @override
  Future<GameStats?> statsFor(Difficulty difficulty) async {
    final all = _records.where((r) => r.difficulty == difficulty).toList();
    if (all.isEmpty) return null;
    final completed = all.where((r) => r.isCompleted).toList();
    final bestSeconds = completed.isEmpty
        ? -1
        : completed.map((r) => r.elapsedSeconds).reduce(math.min);
    final avgSeconds = completed.isEmpty
        ? -1
        : (completed.map((r) => r.elapsedSeconds).reduce((a, b) => a + b) /
                completed.length)
            .round();
    final avgStars = completed.isEmpty
        ? 0.0
        : completed.map((r) => r.stars).reduce((a, b) => a + b) /
            completed.length;
    final totalSeconds =
        all.map((r) => r.elapsedSeconds).reduce((a, b) => a + b);
    return GameStats(
      gamesCompleted: completed.length,
      gamesPlayed: all.length,
      bestSeconds: bestSeconds,
      avgStars: avgStars,
      avgSeconds: avgSeconds,
      totalSeconds: totalSeconds,
    );
  }

  @override
  Future<bool> hasCompletedDailyToday() async {
    final today = DateTime.now();
    return _records.any((r) =>
        r.difficulty == Difficulty.daily &&
        r.isCompleted &&
        r.completedAt.year == today.year &&
        r.completedAt.month == today.month &&
        r.completedAt.day == today.day);
  }
}
```

- [ ] **Step 4: Run tests**

```
flutter test test/data/repositories/memory_game_record_repository_test.dart
```

Expected: PASS (6 tests).

- [ ] **Step 5: Run all tests**

```
flutter test
```

Expected: All tests pass (62 existing + 3 model + 9 local + 6 memory = 80 tests).

- [ ] **Step 6: Commit**

```
git add lib/data/repositories/memory_game_record_repository.dart test/data/repositories/memory_game_record_repository_test.dart
git commit -m "feat: add MemoryGameRecordRepository"
```

---

### Task 5: daily_9x9.json + fetchDaily() date rotation

**Files:**
- Create: `assets/puzzles/daily_9x9.json`
- Modify: `lib/data/repositories/local_puzzle_repository.dart` (lines 45–50)
- Modify: `lib/data/repositories/memory_puzzle_repository.dart` (lines 92–95)

Note: `pubspec.yaml` uses `assets/puzzles/` glob — no change needed there.

- [ ] **Step 1: Create `assets/puzzles/daily_9x9.json`**

```json
{
  "puzzles": [
    {
      "id": 9001,
      "size": 9,
      "difficulty": "daily",
      "initial": [
        [5,3,0,0,7,0,0,0,0],
        [6,0,0,1,9,5,0,0,0],
        [0,9,8,0,0,0,0,6,0],
        [8,0,0,0,6,0,0,0,3],
        [4,0,0,8,0,3,0,0,1],
        [7,0,0,0,2,0,0,0,6],
        [0,6,0,0,0,0,2,8,0],
        [0,0,0,4,1,9,0,0,5],
        [0,0,0,0,8,0,0,7,9]
      ],
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
      "ice_blocks": [],
      "fixed_positions": [
        [0,0],[0,1],[0,4],
        [1,0],[1,3],[1,4],[1,5],
        [2,1],[2,2],
        [3,0],[3,4],[3,8],
        [4,0],[4,3],[4,5],[4,8],
        [5,0],[5,4],[5,8],
        [6,1],[6,6],[6,7],
        [7,3],[7,4],[7,5],[7,8],
        [8,4],[8,7],[8,8]
      ]
    },
    {
      "id": 9002,
      "size": 9,
      "difficulty": "daily",
      "initial": [
        [0,0,0,2,6,0,7,0,1],
        [6,8,0,0,7,0,0,9,0],
        [1,9,0,0,0,4,5,0,0],
        [8,2,0,1,0,0,0,4,0],
        [0,0,4,6,0,2,9,0,0],
        [0,5,0,0,0,3,0,2,8],
        [0,0,9,3,0,0,0,7,4],
        [0,4,0,0,5,0,0,3,6],
        [7,0,3,0,1,8,0,0,0]
      ],
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
      "ice_blocks": [],
      "fixed_positions": [
        [0,3],[0,4],[0,6],[0,8],
        [1,0],[1,1],[1,4],[1,7],
        [2,0],[2,1],[2,5],[2,6],
        [3,0],[3,1],[3,3],[3,7],
        [4,2],[4,3],[4,5],[4,6],
        [5,1],[5,5],[5,7],[5,8],
        [6,2],[6,3],[6,7],[6,8],
        [7,1],[7,4],[7,7],[7,8],
        [8,0],[8,2],[8,4],[8,5]
      ]
    },
    {
      "id": 9003,
      "size": 9,
      "difficulty": "daily",
      "initial": [
        [0,0,0,0,0,0,2,0,0],
        [0,8,0,0,3,0,0,7,0],
        [3,0,0,0,0,1,0,0,6],
        [0,0,1,0,5,0,7,0,0],
        [0,3,0,0,0,0,0,6,0],
        [0,0,9,0,4,0,3,0,0],
        [4,0,0,5,0,0,0,0,7],
        [0,2,0,0,9,0,0,1,0],
        [0,0,5,0,0,0,0,0,0]
      ],
      "solution": [
        [9,6,7,3,8,4,2,5,1],
        [2,8,4,6,3,5,1,7,9],
        [3,5,1,9,2,1,8,4,6],
        [6,4,1,2,5,3,7,9,8],
        [7,3,2,8,1,9,5,6,4],
        [5,1,9,7,4,6,3,8,2],
        [4,9,6,5,7,2,8,3,7],
        [8,2,3,4,9,7,6,1,5],
        [1,7,5,1,6,8,4,2,3]
      ],
      "ice_blocks": [],
      "fixed_positions": [
        [0,6],
        [1,1],[1,4],[1,7],
        [2,0],[2,5],[2,8],
        [3,2],[3,4],[3,6],
        [4,1],[4,7],
        [5,2],[5,4],[5,6],
        [6,0],[6,3],[6,8],
        [7,1],[7,4],[7,7],
        [8,2]
      ]
    }
  ]
}
```

- [ ] **Step 2: Replace `fetchDaily()` in `lib/data/repositories/local_puzzle_repository.dart`**

Replace the existing `fetchDaily()` method (lines 45–51):

```dart
@override
Future<domain.Puzzle?> fetchDaily() async {
  final all = await fetchByDifficulty(domain.Difficulty.daily);
  if (all.isEmpty) return null;
  all.sort((a, b) => a.id.compareTo(b.id));
  final epoch = DateTime(2026, 1, 1);
  final index = DateTime.now().difference(epoch).inDays % all.length;
  return all[index];
}
```

- [ ] **Step 3: Replace `fetchDaily()` in `lib/data/repositories/memory_puzzle_repository.dart`**

Replace lines 92–95:

```dart
@override
Future<Puzzle?> fetchDaily() async {
  await _ensureLoaded();
  final all = _puzzles.where((p) => p.difficulty == Difficulty.daily).toList();
  if (all.isEmpty) return null;
  all.sort((a, b) => a.id.compareTo(b.id));
  final epoch = DateTime(2026, 1, 1);
  final index = DateTime.now().difference(epoch).inDays % all.length;
  return all[index];
}
```

- [ ] **Step 4: Run all tests**

```
flutter test
```

Expected: All tests still pass.

- [ ] **Step 5: Commit**

```
git add assets/puzzles/daily_9x9.json lib/data/repositories/local_puzzle_repository.dart lib/data/repositories/memory_puzzle_repository.dart
git commit -m "feat: add daily puzzle pool and date-rotation fetchDaily()"
```

---

### Task 6: Inject GameRecordRepository in main.dart

**Files:**
- Modify: `lib/main.dart`

Context: `main.dart` currently wraps `AudioService` in `RepositoryProvider`. We need to wrap both in a `MultiRepositoryProvider`. On native (non-web) we use `LocalGameRecordRepository`; on web we use `MemoryGameRecordRepository`.

- [ ] **Step 1: Replace `lib/main.dart`**

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/audio_service.dart';
import 'core/theme/app_theme.dart';
import 'data/local/database/app_database.dart';
import 'data/local/prefs/preferences_service.dart';
import 'data/repositories/local_game_record_repository.dart';
import 'data/repositories/local_puzzle_repository.dart';
import 'data/repositories/local_progress_repository.dart';
import 'data/repositories/memory_game_record_repository.dart';
import 'data/repositories/memory_puzzle_repository.dart';
import 'data/repositories/memory_progress_repository.dart';
import 'domain/repositories/game_record_repository.dart';
import 'domain/repositories/puzzle_repository.dart';
import 'domain/repositories/progress_repository.dart';
import 'presentation/bloc/settings/settings_bloc.dart';
import 'presentation/bloc/settings/settings_state.dart';
import 'presentation/screens/difficulty_select/difficulty_select_screen.dart';
import 'presentation/screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  late PuzzleRepository puzzleRepo;
  late ProgressRepository progressRepo;
  late GameRecordRepository gameRecordRepo;
  late PreferencesService prefs;

  if (kIsWeb) {
    puzzleRepo = MemoryPuzzleRepository();
    progressRepo = MemoryProgressRepository();
    gameRecordRepo = MemoryGameRecordRepository();
    prefs = PreferencesService(await SharedPreferences.getInstance());
  } else {
    final db = AppDatabase();
    final localPuzzleRepo = LocalPuzzleRepository(db);
    await _seedPuzzles(localPuzzleRepo);
    puzzleRepo = localPuzzleRepo;
    progressRepo = LocalProgressRepository(db);
    gameRecordRepo = LocalGameRecordRepository(db);
    prefs = PreferencesService(await SharedPreferences.getInstance());
  }

  final audioService = AudioService();

  runApp(GravitySudokuApp(
    prefs: prefs,
    audioService: audioService,
    puzzleRepo: puzzleRepo,
    progressRepo: progressRepo,
    gameRecordRepo: gameRecordRepo,
  ));
}

Future<void> _seedPuzzles(LocalPuzzleRepository repo) async {
  final files = [
    'assets/puzzles/tutorial_4x4.json',
    'assets/puzzles/easy_4x4.json',
    'assets/puzzles/normal_9x9.json',
    'assets/puzzles/hard_12x12.json',
    'assets/puzzles/expert_16x16.json',
    'assets/puzzles/extreme_32x32.json',
    'assets/puzzles/daily_9x9.json',
  ];
  for (final path in files) {
    try {
      final raw = await rootBundle.loadString(path);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final puzzles = data['puzzles'] as List;
      for (final p in puzzles) {
        await repo.insertFromJson(p as Map<String, dynamic>);
      }
    } catch (_) {}
  }
}

class GravitySudokuApp extends StatelessWidget {
  final PreferencesService prefs;
  final AudioService audioService;
  final PuzzleRepository puzzleRepo;
  final ProgressRepository progressRepo;
  final GameRecordRepository gameRecordRepo;

  const GravitySudokuApp({
    super.key,
    required this.prefs,
    required this.audioService,
    required this.puzzleRepo,
    required this.progressRepo,
    required this.gameRecordRepo,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AudioService>.value(value: audioService),
        RepositoryProvider<GameRecordRepository>.value(value: gameRecordRepo),
      ],
      child: BlocProvider(
        create: (_) => SettingsBloc(prefs, audioService),
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settings) => MaterialApp(
            title: 'Gravity Sudoku',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode:
                settings.theme == 'dark' ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/',
            onGenerateRoute: (routeSettings) {
              switch (routeSettings.name) {
                case '/':
                  return MaterialPageRoute(
                      builder: (_) => const HomeScreen());
                case '/difficulty':
                  return MaterialPageRoute(
                    builder: (_) =>
                        DifficultySelectScreen(puzzleRepo: puzzleRepo),
                  );
                default:
                  return MaterialPageRoute(
                      builder: (_) => const HomeScreen());
              }
            },
          ),
        ),
      ),
    );
  }
}
```

Note: `HomeScreen` still uses `const HomeScreen()` here. Task 10 updates both `HomeScreen` and these routes together to avoid a compile error in between.

- [ ] **Step 2: Run `flutter analyze`**

```
flutter analyze
```

Expected: No errors (HomeScreen may show a warning that `puzzleRepo` param doesn't exist yet — that's fine, Task 10 adds it).

- [ ] **Step 3: Commit**

```
git add lib/main.dart
git commit -m "feat: inject GameRecordRepository via MultiRepositoryProvider in main.dart"
```

---

### Task 7: Record write points — CompletionScreen, GameOverScreen, game_screen Quit

**Files:**
- Modify: `lib/presentation/screens/completion/completion_screen.dart`
- Modify: `lib/presentation/screens/game_over/game_over_screen.dart`
- Modify: `lib/presentation/screens/game/game_screen.dart`

Context: `GameRecordRepository` is in the widget tree via `RepositoryProvider`. Use `context.read<GameRecordRepository>()` inside `didChangeDependencies` (with a flag guard, matching the pattern used in `_GameViewState`). `GameOverScreen` needs a new `elapsedSeconds` param. `game_screen.dart` passes it from `state.elapsedSeconds` and writes a record on Quit.

- [ ] **Step 1: Replace `lib/presentation/screens/completion/completion_screen.dart`**

```dart
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/game_record.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/repositories/game_record_repository.dart';
import '../../../domain/repositories/puzzle_repository.dart';
import '../game/game_screen.dart';

class CompletionScreen extends StatefulWidget {
  final int stars;
  final int elapsedSeconds;
  final Puzzle puzzle;
  final PuzzleRepository puzzleRepo;

  const CompletionScreen({
    super.key,
    required this.stars,
    required this.elapsedSeconds,
    required this.puzzle,
    required this.puzzleRepo,
  });

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
  late ConfettiController _confetti;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_recorded) {
      _recorded = true;
      _saveRecord();
    }
  }

  Future<void> _saveRecord() async {
    final repo = context.read<GameRecordRepository>();
    await repo.insert(GameRecord(
      id: 0,
      difficulty: widget.puzzle.difficulty,
      elapsedSeconds: widget.elapsedSeconds,
      stars: widget.stars,
      isCompleted: true,
      completedAt: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.elapsedSeconds ~/ 60;
    final s = widget.elapsedSeconds % 60;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.puzzle.difficulty == Difficulty.daily
                      ? '今日挑戰完成！'
                      : 'Puzzle Complete!',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Icon(
                      i < widget.stars ? Icons.star : Icons.star_border,
                      color: AppColors.hint,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Time: ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: widget.puzzle.difficulty == Difficulty.daily
                      ? () => Navigator.of(context).popUntil((r) => r.isFirst)
                      : () => _continueSameDifficulty(context),
                  child: Text(widget.puzzle.difficulty == Difficulty.daily
                      ? '回首頁'
                      : '繼續相同難度'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('選難度'),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _continueSameDifficulty(BuildContext context) async {
    final newPuzzle = await widget.puzzleRepo.fetchRandom(
      widget.puzzle.difficulty,
      excludeId: widget.puzzle.id,
    );
    if (newPuzzle == null || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          puzzle: newPuzzle,
          puzzleRepo: widget.puzzleRepo,
        ),
      ),
      (route) => route.isFirst,
    );
  }
}
```

- [ ] **Step 2: Replace `lib/presentation/screens/game_over/game_over_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/models/game_record.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/repositories/game_record_repository.dart';
import '../../../domain/repositories/puzzle_repository.dart';
import '../game/game_screen.dart';

class GameOverScreen extends StatefulWidget {
  final Puzzle puzzle;
  final PuzzleRepository puzzleRepo;
  final VoidCallback? onRestart;
  final bool isInfiniteMode;
  final int elapsedSeconds;

  const GameOverScreen({
    super.key,
    required this.puzzle,
    required this.puzzleRepo,
    required this.elapsedSeconds,
    this.onRestart,
    this.isInfiniteMode = false,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  bool _recorded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_recorded) {
      _recorded = true;
      _saveRecord();
    }
  }

  Future<void> _saveRecord() async {
    final repo = context.read<GameRecordRepository>();
    await repo.insert(GameRecord(
      id: 0,
      difficulty: widget.puzzle.difficulty,
      elapsedSeconds: widget.elapsedSeconds,
      stars: 0,
      isCompleted: false,
      completedAt: DateTime.now(),
    ));
  }

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
            const Text(
              'You ran out of lives.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onRestart?.call();
              },
              child: const Text('重新開始'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _newLevel(context),
              child: const Text('換一關'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _newLevel(BuildContext context) async {
    final newPuzzle = await widget.puzzleRepo.fetchRandom(
      widget.puzzle.difficulty,
      excludeId: widget.puzzle.id,
    );
    if (newPuzzle == null || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          puzzle: newPuzzle,
          puzzleRepo: widget.puzzleRepo,
          isInfiniteMode: widget.isInfiniteMode,
        ),
      ),
      (route) => route.isFirst,
    );
  }
}
```

- [ ] **Step 3: Update `game_screen.dart` — pass `elapsedSeconds` to GameOverScreen + Quit saves record**

In `lib/presentation/screens/game/game_screen.dart`, find the `GameOverScreen` push in the `BlocListener` (around line 99) and update to add `elapsedSeconds: state.elapsedSeconds`:

```dart
} else if (state.status == GameStatus.gameOver) {
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
```

Also update the "Quit" button in `_showPauseMenu` (around line 265). Add the import `import '../../../domain/repositories/game_record_repository.dart';` and `import '../../../domain/models/game_record.dart';` at the top. Then replace the Quit TextButton:

```dart
TextButton(
  onPressed: () async {
    final bloc = context.read<GameBloc>();
    final repo = context.read<GameRecordRepository>();
    final s = bloc.state;
    await repo.insert(GameRecord(
      id: 0,
      difficulty: widget.puzzle.difficulty,
      elapsedSeconds: s.elapsedSeconds,
      stars: 0,
      isCompleted: false,
      completedAt: DateTime.now(),
    ));
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) Navigator.of(context).pop();
  },
  child: const Text('Quit'),
),
```

- [ ] **Step 4: Run `flutter analyze`**

```
flutter analyze
```

Expected: No errors.

- [ ] **Step 5: Run all tests**

```
flutter test
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```
git add lib/presentation/screens/completion/completion_screen.dart lib/presentation/screens/game_over/game_over_screen.dart lib/presentation/screens/game/game_screen.dart
git commit -m "feat: save GameRecord on completion, game over, and quit"
```

---

### Task 8: LeaderboardScreen

**Files:**
- Create: `lib/presentation/screens/leaderboard/leaderboard_screen.dart`

- [ ] **Step 1: Create `lib/presentation/screens/leaderboard/leaderboard_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/game_record.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/repositories/game_record_repository.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  static const _tabs = [
    (Difficulty.easy, 'Easy'),
    (Difficulty.normal, 'Normal'),
    (Difficulty.hard, 'Hard'),
    (Difficulty.expert, 'Expert'),
    (Difficulty.extreme, 'Extreme'),
    (Difficulty.daily, '每日挑戰'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('排行榜'),
          bottom: TabBar(
            isScrollable: true,
            tabs: _tabs.map((t) => Tab(text: t.$2)).toList(),
          ),
        ),
        body: TabBarView(
          children: _tabs
              .map((t) => _LeaderboardTab(difficulty: t.$1))
              .toList(),
        ),
      ),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  final Difficulty difficulty;
  const _LeaderboardTab({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GameRecordRepository>();
    return FutureBuilder<List<GameRecord>>(
      future: repo.topN(difficulty),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snap.data ?? [];
        if (records.isEmpty) {
          return const Center(child: Text('尚無記錄，快來挑戰！'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: records.length,
          itemBuilder: (_, i) => _RankRow(rank: i + 1, record: records[i]),
        );
      },
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final GameRecord record;
  const _RankRow({required this.rank, required this.record});

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    final date = record.completedAt;
    final dateStr =
        '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isFirst
            ? AppColors.primary.withValues(alpha: 0.12)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFirst
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isFirst ? AppColors.primary : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _formatTime(record.elapsedSeconds),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            children: List.generate(
              3,
              (i) => Icon(
                i < record.stars ? Icons.star : Icons.star_border,
                size: 16,
                color: AppColors.hint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(dateStr,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run `flutter analyze`**

```
flutter analyze
```

Expected: No issues in the new file.

- [ ] **Step 3: Commit**

```
git add lib/presentation/screens/leaderboard/leaderboard_screen.dart
git commit -m "feat: add LeaderboardScreen with per-difficulty top-10"
```

---

### Task 9: StatsScreen

**Files:**
- Create: `lib/presentation/screens/stats/stats_screen.dart`

- [ ] **Step 1: Create `lib/presentation/screens/stats/stats_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/game_record.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/repositories/game_record_repository.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static const _tabs = [
    (Difficulty.easy, 'Easy'),
    (Difficulty.normal, 'Normal'),
    (Difficulty.hard, 'Hard'),
    (Difficulty.expert, 'Expert'),
    (Difficulty.extreme, 'Extreme'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('統計'),
          bottom: TabBar(
            isScrollable: true,
            tabs: _tabs.map((t) => Tab(text: t.$2)).toList(),
          ),
        ),
        body: TabBarView(
          children: _tabs.map((t) => _StatsTab(difficulty: t.$1)).toList(),
        ),
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  final Difficulty difficulty;
  const _StatsTab({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GameRecordRepository>();
    return FutureBuilder<GameStats?>(
      future: repo.statsFor(difficulty),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snap.data;
        if (stats == null) {
          return const Center(child: Text('尚無資料'));
        }
        return _StatsBody(stats: stats);
      },
    );
  }
}

class _StatsBody extends StatelessWidget {
  final GameStats stats;
  const _StatsBody({required this.stats});

  String _formatTime(int seconds) {
    if (seconds < 0) return '--:--';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTotal(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  String _winRate() {
    if (stats.gamesPlayed == 0) return '0%';
    return '${(stats.gamesCompleted / stats.gamesPlayed * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(label: '完成場數', value: '${stats.gamesCompleted}')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: '勝率', value: _winRate())),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(label: '最佳時間', value: _formatTime(stats.bestSeconds))),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: '平均時間', value: _formatTime(stats.avgSeconds))),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: '總遊玩時間', value: _formatTotal(stats.totalSeconds))),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(
            label: '平均星數',
            value: '${stats.avgStars.toStringAsFixed(1)} / 3',
            child: Row(
              children: List.generate(
                3,
                (i) => Icon(
                  i < stats.avgStars.round() ? Icons.star : Icons.star_border,
                  size: 20,
                  color: AppColors.hint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget? child;
  const _StatCard({required this.label, required this.value, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          if (child != null) child!,
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run `flutter analyze`**

```
flutter analyze
```

Expected: No issues.

- [ ] **Step 3: Commit**

```
git add lib/presentation/screens/stats/stats_screen.dart
git commit -m "feat: add StatsScreen with per-difficulty aggregated statistics"
```

---

### Task 10: HomeScreen wiring — daily challenge + leaderboard + stats buttons

**Files:**
- Modify: `lib/presentation/screens/home/home_screen.dart`

Context: `HomeScreen` becomes a `StatefulWidget`. It accepts `puzzleRepo` (needed for the daily challenge fetch). It checks `hasCompletedDailyToday()` in `didChangeDependencies`. The daily button shows "今日已完成 ✓" when done. Two new buttons navigate to `LeaderboardScreen` and `StatsScreen`.

Also update `main.dart` route registration in Step 2 (the `/` and default routes currently use `const HomeScreen()` and need to be updated to `HomeScreen(puzzleRepo: puzzleRepo)`).

- [ ] **Step 1: Replace `lib/presentation/screens/home/home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/repositories/game_record_repository.dart';
import '../../../domain/repositories/puzzle_repository.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../bloc/settings/settings_event.dart';
import '../../bloc/settings/settings_state.dart';
import '../difficulty_select/difficulty_select_screen.dart';
import '../game/game_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../stats/stats_screen.dart';

class HomeScreen extends StatefulWidget {
  final PuzzleRepository puzzleRepo;
  const HomeScreen({super.key, required this.puzzleRepo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _dailyDone = false;
  bool _dailyChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dailyChecked) {
      _dailyChecked = true;
      context
          .read<GameRecordRepository>()
          .hasCompletedDailyToday()
          .then((done) {
        if (mounted) setState(() => _dailyDone = done);
      });
    }
  }

  Future<void> _startDaily(BuildContext context) async {
    final puzzle = await widget.puzzleRepo.fetchDaily();
    if (puzzle == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        puzzle: puzzle,
        puzzleRepo: widget.puzzleRepo,
        isInfiniteMode: false,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settings) => Scaffold(
        appBar: AppBar(
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
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Gravity Sudoku',
                  style:
                      TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sudoku meets gravity',
                  style: TextStyle(
                      fontSize: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 60),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/difficulty'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    child:
                        Text('Play', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed:
                      _dailyDone ? null : () => _startDaily(context),
                  child: Text(
                    _dailyDone ? '今日已完成 ✓' : 'Daily Challenge',
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen()),
                  ),
                  child: const Text('排行'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const StatsScreen()),
                  ),
                  child: const Text('統計'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update `main.dart` routes to pass `puzzleRepo` to `HomeScreen`**

In `lib/main.dart`, find the two `HomeScreen` usages in `onGenerateRoute` (around lines 103–111) and update:

```dart
case '/':
  return MaterialPageRoute(
      builder: (_) => HomeScreen(puzzleRepo: puzzleRepo));
// ...
default:
  return MaterialPageRoute(
      builder: (_) => HomeScreen(puzzleRepo: puzzleRepo));
```

Also remove the `const` keyword since `HomeScreen` now requires a runtime parameter.

- [ ] **Step 3: Run `flutter analyze`**

```
flutter analyze
```

Expected: No issues.

- [ ] **Step 4: Run all tests**

```
flutter test
```

Expected: All tests pass. The existing bloc tests don't depend on `HomeScreen` so they're unaffected.

- [ ] **Step 5: Commit**

```
git add lib/presentation/screens/home/home_screen.dart lib/main.dart
git commit -m "feat: wire HomeScreen with daily challenge state, leaderboard, and stats navigation"
```

---

## Done

All 10 tasks complete. Run the full test suite one final time:

```
flutter test
```

Expected: All tests pass (62 existing + 3 model + 9 local repo + 6 memory repo = 80 tests).

Run analyzer:

```
flutter analyze
```

Expected: No issues.
