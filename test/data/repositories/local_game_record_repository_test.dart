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
