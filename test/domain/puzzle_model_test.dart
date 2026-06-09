import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/puzzle.dart';

void main() {
  final board = Board.empty(4);

  test('Difficulty.tutorial exists', () {
    expect(Difficulty.tutorial, isA<Difficulty>());
  });

  test('Puzzle has nullable tutorialStep', () {
    final p = Puzzle(
      id: -1, size: 4,
      difficulty: Difficulty.tutorial,
      initialBoard: board, solution: board,
      tutorialStep: 'Hello',
    );
    expect(p.tutorialStep, 'Hello');

    final p2 = Puzzle(
      id: 1, size: 4,
      difficulty: Difficulty.easy,
      initialBoard: board, solution: board,
    );
    expect(p2.tutorialStep, isNull);
  });
}
