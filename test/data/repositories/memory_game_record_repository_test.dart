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
