import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';
import 'package:gravity_sudoku/domain/services/gravity_engine.dart';
import 'package:gravity_sudoku/domain/services/hint_service.dart';
import 'package:gravity_sudoku/domain/services/sudoku_validator.dart';

void main() {
  late HintService hints;

  setUp(() {
    hints = HintService(
      gravity: GravityEngine(),
      validator: SudokuValidator(),
    );
  });

  test('returns null for complete board', () {
    var b = Board.empty(4);
    final vals = [
      [1,2,3,4],[3,4,1,2],[2,1,4,3],[4,3,2,1]
    ];
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        b = b.setCell(r, c, Cell(value: vals[r][c]));
      }
    }
    expect(hints.suggest(b, boardSize: 4), isNull);
  });

  test('returns a valid move on partially filled board', () {
    var b = Board.empty(4);
    b = b.setCell(1, 0, const Cell(value: 2));
    b = b.setCell(2, 0, const Cell(value: 3));
    b = b.setCell(3, 0, const Cell(value: 4));
    final hint = hints.suggest(b, boardSize: 4);
    expect(hint, isNotNull);
    expect(hint!.col, 0);
    expect(hint.row, 0);
  });
}
