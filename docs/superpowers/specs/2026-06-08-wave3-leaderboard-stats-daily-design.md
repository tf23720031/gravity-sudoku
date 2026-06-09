# Wave 3: 排行榜 + 統計 + 每日挑戰 Design

## Goal

Add three player-experience features sharing a single `GameRecord` persistence layer: per-difficulty local leaderboards (top 10 best times), a full statistics page (per difficulty), and a daily challenge (one puzzle per day, rotating from the `daily` pool).

---

## Architecture

All three features read from a new `game_records` Drift table. No BLoC is added for these screens — `FutureBuilder` is sufficient. `GameRecordRepository` is injected at the app root via `RepositoryProvider` (same pattern as `AudioService`), making it available via `context.read<GameRecordRepository>()` without threading it through every constructor.

---

## 1. Data Layer

### GameRecord model

```dart
// lib/domain/models/game_record.dart
class GameRecord {
  final int id;
  final Difficulty difficulty;
  final int elapsedSeconds;
  final int stars;        // 0 when isCompleted = false
  final bool isCompleted;
  final DateTime completedAt;
}
```

### GameStats model

```dart
// lib/domain/models/game_record.dart (same file)
class GameStats {
  final int gamesCompleted;
  final int gamesPlayed;
  final int bestSeconds;       // -1 if no completions
  final double avgStars;
  final int avgSeconds;        // -1 if no completions
  final int totalSeconds;
}
```

### Drift table

```dart
// Appended to lib/data/local/database/app_database.dart
class GameRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get difficulty => text()();
  IntColumn get elapsedSeconds => integer()();
  IntColumn get stars => integer()();
  BoolColumn get isCompleted => boolean()();
  IntColumn get completedAt => integer()();  // Unix ms
}
```

Schema version bumped from 1 → 2 with migration:

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 2) await m.createTable(gameRecords);
  },
);
```

`@DriftDatabase(tables: [Puzzles, Progresses, GameRecords])`

### GameRecordRepository interface

```dart
// lib/domain/repositories/game_record_repository.dart
abstract class GameRecordRepository {
  Future<void> insert(GameRecord record);
  Future<List<GameRecord>> topN(Difficulty difficulty, {int n = 10});
  Future<GameStats?> statsFor(Difficulty difficulty);
  Future<bool> hasCompletedDailyToday();
}
```

### LocalGameRecordRepository

```dart
// lib/data/repositories/local_game_record_repository.dart
// Import domain model with alias to avoid collision with Drift-generated row type:
// import '../../domain/models/game_record.dart' as domain;
// import '../../domain/models/puzzle.dart' as puzzle_domain;
// import 'dart:math' as math;
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
  Future<List<domain.GameRecord>> topN(puzzle_domain.Difficulty difficulty, {int n = 10}) async {
    final rows = await (_db.select(_db.gameRecords)
          ..where((r) =>
              r.difficulty.equals(difficulty.name) &
              r.isCompleted.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.elapsedSeconds)])
          ..limit(n))
        .get();
    return rows.map(_rowToRecord).toList();
  }

  @override
  Future<domain.GameStats?> statsFor(puzzle_domain.Difficulty difficulty) async {
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
    final totalSeconds = all.map((r) => r.elapsedSeconds).reduce((a, b) => a + b);
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
    final startMs = DateTime(today.year, today.month, today.day)
        .millisecondsSinceEpoch;
    final endMs = startMs + const Duration(days: 1).inMilliseconds;
    final rows = await (_db.select(_db.gameRecords)
          ..where((r) =>
              r.difficulty.equals(puzzle_domain.Difficulty.daily.name) &
              r.isCompleted.equals(true) &
              r.completedAt.isBiggerOrEqualValue(startMs) &
              r.completedAt.isSmallerThanValue(endMs)))
        .get();
    return rows.isNotEmpty;
  }

  // Parameter type is the Drift-generated row type (auto-named GameRecord by Drift).
  // Return type is the domain model (aliased as domain.GameRecord).
  domain.GameRecord _rowToRecord(GameRecord row) => domain.GameRecord(
        id: row.id,
        difficulty: puzzle_domain.Difficulty.values.byName(row.difficulty),
        elapsedSeconds: row.elapsedSeconds,
        stars: row.stars,
        isCompleted: row.isCompleted,
        completedAt: DateTime.fromMillisecondsSinceEpoch(row.completedAt),
      );
}
```

### MemoryGameRecordRepository

```dart
// lib/data/repositories/memory_game_record_repository.dart
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
    return GameStats(
      gamesCompleted: completed.length,
      gamesPlayed: all.length,
      bestSeconds: completed.isEmpty ? -1 : completed.map((r) => r.elapsedSeconds).reduce(math.min),
      avgStars: completed.isEmpty ? 0.0 : completed.map((r) => r.stars).reduce((a, b) => a + b) / completed.length,
      avgSeconds: completed.isEmpty ? -1 : (completed.map((r) => r.elapsedSeconds).reduce((a, b) => a + b) / completed.length).round(),
      totalSeconds: all.map((r) => r.elapsedSeconds).reduce((a, b) => a + b),
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

### Dependency injection (main.dart)

`GameRecordRepository` is created in `main()` and wrapped as a `RepositoryProvider` alongside `AudioService`:

```dart
// Non-web:
final gameRecordRepo = LocalGameRecordRepository(db);
// Web:
final gameRecordRepo = MemoryGameRecordRepository();

// In GravitySudokuApp.build:
MultiRepositoryProvider(
  providers: [
    RepositoryProvider<AudioService>.value(value: audioService),
    RepositoryProvider<GameRecordRepository>.value(value: gameRecordRepo),
  ],
  child: BlocProvider(...),
)
```

---

## 2. Record Write Points

### CompletionScreen — isCompleted: true

`CompletionScreen` uses `didChangeDependencies` with a `_recorded` flag (matching the existing `_GameViewState` pattern) to safely call `context.read` after the widget is in the tree:

```dart
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
```

### GameOverScreen — isCompleted: false

`GameOverScreen` gains `final int elapsedSeconds` param (passed from `game_screen.dart`'s `state.elapsedSeconds`):

```dart
// In game_screen.dart BlocListener, gameOver branch:
GameOverScreen(
  puzzle: widget.puzzle,
  puzzleRepo: widget.puzzleRepo,
  isInfiniteMode: state.isInfiniteMode,
  elapsedSeconds: state.elapsedSeconds,
  onRestart: ...
)
```

`GameOverScreen.initState` inserts `isCompleted: false, stars: 0`.

### Quit (pause menu) — isCompleted: false

In `game_screen.dart _showPauseMenu`, the "Quit" `TextButton.onPressed`:

```dart
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
  Navigator.pop(context);
  if (context.mounted) Navigator.of(context).pop();
},
```

---

## 3. Daily Challenge

### Puzzle asset

New file `assets/puzzles/daily_9x9.json` — contains an array of 9×9 puzzles with `"difficulty": "daily"`. Seeded in `_seedPuzzles()`.

### fetchDaily() rotation

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

### HomeScreen changes

Convert to `StatefulWidget`. Load `hasCompletedDailyToday()` in `initState` and on `didChangeDependencies`. Show:
- If not completed: standard "Daily Challenge" button
- If completed: greyed-out button with "今日已完成 ✓" label

```dart
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
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
      context.read<GameRecordRepository>()
          .hasCompletedDailyToday()
          .then((done) {
        if (mounted) setState(() => _dailyDone = done);
      });
    }
  }
  // ...
}
```

Two new TextButton entries added below "Daily Challenge":
```dart
TextButton(onPressed: () => Navigator.of(context).push(...LeaderboardScreen...), child: const Text('排行')),
TextButton(onPressed: () => Navigator.of(context).push(...StatsScreen...), child: const Text('統計')),
```

---

## 4. LeaderboardScreen

```dart
// lib/presentation/screens/leaderboard/leaderboard_screen.dart
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});
}
```

`DefaultTabController` with 6 tabs: Easy / Normal / Hard / Expert / Extreme / 每日挑戰.

Each tab is a `_LeaderboardTab(difficulty: d)` widget that uses `FutureBuilder` on `repo.topN(difficulty)`.

**Row format:**
```
#1  02:34  ★★★  06/08
#2  03:12  ★★☆  06/07
```

- Rank, time (MM:SS), star icons, date (MM/dd)
- Rank 1 row gets a light gold background tint
- Empty state: `Center(child: Text('尚無記錄，快來挑戰！'))`

---

## 5. StatsScreen

```dart
// lib/presentation/screens/stats/stats_screen.dart
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
}
```

Same tab structure (Easy / Normal / Hard / Expert / Extreme), no 每日挑戰 tab.

Each tab is `_StatsTab(difficulty: d)` using `FutureBuilder` on `repo.statsFor(difficulty)`.

**Layout (when data exists):**
```
完成場數      勝率
   12         75%

最佳時間    平均時間    總遊玩時間
  02:34      04:12       1h 23m

平均星數
★★☆  (2.3 / 3)
```

Helper: `_formatTime(int seconds) → String` — outputs `HH:mm:ss` for ≥1h, `MM:SS` otherwise.

Empty state: `Center(child: Text('尚無資料'))`

---

## Files Changed

| File | Change |
|------|--------|
| `lib/data/local/database/app_database.dart` | + `GameRecords` table; schema → 2; migration |
| `lib/domain/models/game_record.dart` | New: `GameRecord`, `GameStats` |
| `lib/domain/repositories/game_record_repository.dart` | New: interface |
| `lib/data/repositories/local_game_record_repository.dart` | New: Drift impl |
| `lib/data/repositories/memory_game_record_repository.dart` | New: in-memory impl |
| `lib/data/repositories/local_puzzle_repository.dart` | Implement `fetchDaily()` rotation |
| `assets/puzzles/daily_9x9.json` | New: daily puzzle pool |
| `pubspec.yaml` | Add `daily_9x9.json` to assets (if not using glob) |
| `lib/main.dart` | Create + inject `GameRecordRepository`; `MultiRepositoryProvider` |
| `lib/presentation/screens/home/home_screen.dart` | StatefulWidget; daily state; new buttons |
| `lib/presentation/screens/leaderboard/leaderboard_screen.dart` | New |
| `lib/presentation/screens/stats/stats_screen.dart` | New |
| `lib/presentation/screens/completion/completion_screen.dart` | `_saveRecord()` in initState |
| `lib/presentation/screens/game_over/game_over_screen.dart` | + `elapsedSeconds` param; save record |
| `lib/presentation/screens/game/game_screen.dart` | Pass `elapsedSeconds` to GameOverScreen; Quit saves record |

---

## Out of Scope

- Syncing records across devices
- Editing or deleting leaderboard entries
- Global/online leaderboard
- Daily challenge mid-game toggle or replay
- Push notifications for daily challenge reminder
