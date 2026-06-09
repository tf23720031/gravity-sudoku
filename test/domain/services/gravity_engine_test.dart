import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';
import 'package:gravity_sudoku/domain/services/gravity_engine.dart';

void main() {
  late GravityEngine engine;

  setUp(() => engine = GravityEngine());

  group('GravityEngine.simulate', () {
    test('number falls to bottom of empty column', () {
      final b = Board.empty(4);
      final result = engine.simulate(b, col: 0, fromRow: 0);
      expect(result.toRow, 3);
      expect(result.fromRow, 0);
      expect(result.moved, isTrue);
    });

    test('number stays when placed at bottom', () {
      final b = Board.empty(4);
      final result = engine.simulate(b, col: 0, fromRow: 3);
      expect(result.toRow, 3);
      expect(result.moved, isFalse);
    });

    test('number stops above existing number', () {
      var b = Board.empty(4);
      b = b.setCell(3, 0, const Cell(value: 2));
      final result = engine.simulate(b, col: 0, fromRow: 0);
      expect(result.toRow, 2);
    });

    test('number stops above ice block', () {
      var b = Board.empty(4);
      b = b.setCell(2, 0, const Cell(isIceBlock: true));
      final result = engine.simulate(b, col: 0, fromRow: 0);
      expect(result.toRow, 1);
    });

    test('number placed below ice block falls to bottom of zone', () {
      var b = Board.empty(4);
      b = b.setCell(1, 0, const Cell(isIceBlock: true));
      final result = engine.simulate(b, col: 0, fromRow: 2);
      expect(result.toRow, 3);
    });

    test('number cannot fall through existing number', () {
      var b = Board.empty(9);
      b = b.setCell(8, 2, const Cell(value: 5));
      b = b.setCell(7, 2, const Cell(value: 3));
      final result = engine.simulate(b, col: 2, fromRow: 0);
      expect(result.toRow, 6);
    });
  });

  group('GravityEngine.apply', () {
    test('places number at gravity-resolved position', () {
      final b = Board.empty(4);
      final result = engine.simulate(b, col: 1, fromRow: 0);
      final newBoard = engine.apply(b, col: 1, value: 3, result: result);
      expect(newBoard.cellAt(3, 1).value, 3);
      expect(newBoard.cellAt(0, 1).isEmpty, isTrue);
    });
  });
}
