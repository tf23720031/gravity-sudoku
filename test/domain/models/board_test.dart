import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';
import 'package:gravity_sudoku/core/utils/position.dart';

void main() {
  group('Board', () {
    test('empty board has all empty cells', () {
      final b = Board.empty(4);
      expect(b.size, 4);
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          expect(b.cellAt(r, c).isEmpty, isTrue);
        }
      }
    });

    test('setCell returns new board with updated cell', () {
      final b = Board.empty(4);
      final b2 = b.setCell(1, 2, const Cell(value: 3));
      expect(b2.cellAt(1, 2).value, 3);
      expect(b.cellAt(1, 2).isEmpty, isTrue);
    });

    test('isComplete false when cells are empty', () {
      expect(Board.empty(4).isComplete, isFalse);
    });

    test('isComplete true when all cells filled or ice', () {
      var b = Board.empty(4);
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          b = b.setCell(r, c, const Cell(value: 1));
        }
      }
      expect(b.isComplete, isTrue);
    });

    test('isComplete true when ice blocks fill remaining', () {
      var b = Board.empty(2);
      b = b.setCell(0, 0, const Cell(value: 1));
      b = b.setCell(0, 1, const Cell(isIceBlock: true));
      b = b.setCell(1, 0, const Cell(value: 2));
      b = b.setCell(1, 1, const Cell(isIceBlock: true));
      expect(b.isComplete, isTrue);
    });
  });

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
      expect(result.board.cellAt(0, 1).value, isNull);
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
}
