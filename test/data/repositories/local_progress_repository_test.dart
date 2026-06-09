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
