import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';
import 'package:gravity_sudoku/domain/services/sudoku_validator.dart';

Board _makeBoard(List<List<int>> grid) {
  final cells = grid
      .map((row) => row
          .map((v) => v == -1
              ? const Cell(isIceBlock: true)
              : v == 0
                  ? const Cell()
                  : Cell(value: v))
          .toList())
      .toList();
  return Board(size: grid.length, cells: cells);
}

void main() {
  late SudokuValidator validator;
  setUp(() => validator = SudokuValidator());

  group('findConflicts', () {
    test('no conflicts on empty board', () {
      expect(validator.findConflicts(Board.empty(4)), isEmpty);
    });

    test('detects row duplicate', () {
      final b = _makeBoard([
        [1, 1, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      final conflicts = validator.findConflicts(b);
      expect(conflicts, containsAll([(0, 0), (0, 1)]));
    });

    test('detects column duplicate', () {
      final b = _makeBoard([
        [2, 0, 0, 0],
        [2, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      final conflicts = validator.findConflicts(b);
      expect(conflicts, containsAll([(0, 0), (1, 0)]));
    });

    test('detects subgrid duplicate for 4x4 (2x2 subgrid)', () {
      final b = _makeBoard([
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      final conflicts = validator.findConflicts(b);
      expect(conflicts, containsAll([(0, 0), (1, 1)]));
    });

    test('no conflicts on valid partial 4x4 board', () {
      final b = _makeBoard([
        [1, 2, 0, 0],
        [3, 4, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      expect(validator.findConflicts(b), isEmpty);
    });
  });

  group('isComplete', () {
    test('complete valid 4x4 board', () {
      final b = _makeBoard([
        [1, 2, 3, 4],
        [3, 4, 1, 2],
        [2, 1, 4, 3],
        [4, 3, 2, 1],
      ]);
      expect(validator.isComplete(b), isTrue);
    });

    test('incomplete board returns false', () {
      final b = _makeBoard([
        [1, 2, 3, 4],
        [3, 4, 1, 2],
        [2, 1, 4, 3],
        [4, 3, 2, 0],
      ]);
      expect(validator.isComplete(b), isFalse);
    });
  });
}
