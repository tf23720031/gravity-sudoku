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
