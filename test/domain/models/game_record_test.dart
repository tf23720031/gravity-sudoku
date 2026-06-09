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
