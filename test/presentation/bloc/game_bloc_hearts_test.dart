import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/core/services/audio_service.dart';
import 'package:gravity_sudoku/core/utils/position.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';
import 'package:gravity_sudoku/domain/models/puzzle.dart';
import 'package:gravity_sudoku/domain/services/gravity_engine.dart';
import 'package:gravity_sudoku/domain/services/hint_service.dart';
import 'package:gravity_sudoku/domain/services/sudoku_validator.dart';
import 'package:gravity_sudoku/presentation/bloc/game/game_bloc.dart';
import 'package:gravity_sudoku/presentation/bloc/game/game_event.dart';
import 'package:gravity_sudoku/presentation/bloc/game/game_state.dart';

class _FakeAudio extends AudioService {
  @override Future<void> playClick() async {}
  @override Future<void> playThud() async {}
  @override Future<void> playError() async {}
  @override Future<void> playComplete() async {}
  @override Future<void> startMusic() async {}
  @override Future<void> stopMusic() async {}
}

// A valid 4x4 Sudoku solution.
// Row 3 (bottom) = [1, 2, 3, 4], so gravity lands there first on an empty board.
final _solution4x4 = Board(
  size: 4,
  cells: [
    [Cell(value: 2), Cell(value: 1), Cell(value: 4), Cell(value: 3)],
    [Cell(value: 4), Cell(value: 3), Cell(value: 2), Cell(value: 1)],
    [Cell(value: 3), Cell(value: 4), Cell(value: 1), Cell(value: 2)],
    [Cell(value: 1), Cell(value: 2), Cell(value: 3), Cell(value: 4)],
  ],
);

// Initial board: fully empty — gravity will always land pieces at row 3.
final _initial4x4 = Board.empty(4);

// Puzzle with known solution; difficulty is easy so solution-checking is active.
final _testPuzzle = Puzzle(
  id: 999,
  size: 4,
  difficulty: Difficulty.easy,
  initialBoard: _initial4x4,
  solution: _solution4x4,
);

GameBloc _makeRealBloc() => GameBloc(
      puzzle: _testPuzzle,
      gravity: GravityEngine(),
      validator: SudokuValidator(),
      hint: HintService(gravity: GravityEngine(), validator: SudokuValidator()),
      audio: _FakeAudio(),
    );

void main() {
  // ── Existing state-shape tests ──────────────────────────────────────────────

  final board = Board.empty(4);

  test('GameState initial non-tutorial has 3 hearts, 1 undo', () {
    final s = GameState.initial(board, isTutorial: false);
    expect(s.hearts, 3);
    expect(s.undosRemaining, 1);
    expect(s.wrongFlashCell, isNull);
  });

  test('GameState initial tutorial has 3 hearts, 99 undos', () {
    final s = GameState.initial(board, isTutorial: true);
    expect(s.hearts, 3);
    expect(s.undosRemaining, 99);
  });

  test('GameStatus.gameOver exists', () {
    expect(GameStatus.gameOver, isA<GameStatus>());
  });

  test('stars: 3 hearts + 0 hints = 3 stars', () {
    final s = GameState.initial(board, isTutorial: false);
    expect(s.stars, 3);
  });

  test('stars: 2 hearts + 0 hints = 2 stars', () {
    final s = GameState.initial(board, isTutorial: false)
        .copyWith(hearts: 2);
    expect(s.stars, 2);
  });

  test('stars: 3 hearts + 2 hints = 1 star', () {
    final s = GameState.initial(board, isTutorial: false)
        .copyWith(hintUsedCount: 2);
    expect(s.stars, 1);
  });

  // ── New GameBloc solution-checking behaviour tests ──────────────────────────
  //
  // _solution4x4 row 3 = [1, 2, 3, 4].
  // On an empty board gravity always lands at row 3.
  //   col 0 → solution value = 1  (symbol '1')
  //   col 1 → solution value = 2  (symbol '2')
  //
  // Placing symbol '2' in col 0 → value 2 ≠ solution[3][0]=1 → WRONG.
  // Placing symbol '1' in col 0 → value 1 = solution[3][0]=1  → CORRECT.

  group('GameBloc solution-checking', () {
    blocTest<GameBloc, GameState>(
      'wrong placement decrements hearts by 1 and sets wrongFlashCell',
      build: _makeRealBloc,
      act: (bloc) => bloc
        ..add(const SelectSymbol('2'))   // value 2, but solution[3][0] = 1
        ..add(const PlaceNumber(0, 0)),
      verify: (bloc) {
        expect(bloc.state.hearts, 2);
        expect(bloc.state.wrongFlashCell, equals(Position(3, 0)));
        expect(bloc.state.status, GameStatus.playing);
      },
    );

    blocTest<GameBloc, GameState>(
      '3 wrong placements transitions status to gameOver',
      build: _makeRealBloc,
      act: (bloc) async {
        // Wrong move 1 — col 0
        bloc.add(const SelectSymbol('2'));
        bloc.add(const PlaceNumber(0, 0));
        await Future<void>.delayed(Duration.zero);
        // Wrong move 2 — col 1  (solution[3][1] = 2, so symbol '3' is wrong)
        bloc.add(const SelectSymbol('3'));
        bloc.add(const PlaceNumber(0, 1));
        await Future<void>.delayed(Duration.zero);
        // Wrong move 3 — col 2  (solution[3][2] = 3, so symbol '4' is wrong)
        bloc.add(const SelectSymbol('4'));
        bloc.add(const PlaceNumber(0, 2));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.hearts, 0);
        expect(bloc.state.status, GameStatus.gameOver);
      },
    );

    blocTest<GameBloc, GameState>(
      'correct placement applies move — board changes and no heart lost',
      build: _makeRealBloc,
      act: (bloc) => bloc
        ..add(const SelectSymbol('1'))   // value 1, solution[3][0] = 1 — correct
        ..add(const PlaceNumber(0, 0)),
      verify: (bloc) {
        expect(bloc.state.hearts, 3);           // hearts unchanged
        expect(bloc.state.wrongFlashCell, isNull);
        expect(bloc.state.board.cellAt(3, 0).value, 1); // piece landed at row 3
        expect(bloc.state.status, GameStatus.playing);
      },
    );

    blocTest<GameBloc, GameState>(
      'WrongFlashCleared event clears wrongFlashCell',
      build: _makeRealBloc,
      act: (bloc) async {
        bloc.add(const SelectSymbol('2'));  // wrong move
        bloc.add(const PlaceNumber(0, 0));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const WrongFlashCleared());
      },
      verify: (bloc) {
        expect(bloc.state.wrongFlashCell, isNull);
      },
    );

    blocTest<GameBloc, GameState>(
      'WrongFlashCleared is ignored when status is gameOver',
      build: _makeRealBloc,
      act: (bloc) async {
        // Three wrong moves to reach gameOver
        bloc.add(const SelectSymbol('2'));
        bloc.add(const PlaceNumber(0, 0));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SelectSymbol('3'));
        bloc.add(const PlaceNumber(0, 1));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SelectSymbol('4'));
        bloc.add(const PlaceNumber(0, 2));
        await Future<void>.delayed(Duration.zero);
        // Attempt to clear wrong flash after game over — should be a no-op
        bloc.add(const WrongFlashCleared());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.status, GameStatus.gameOver);
        // wrongFlashCell may still be set — the important thing is no state
        // change happens and no exception is thrown.
        expect(bloc.state.hearts, 0);
      },
    );
  });
}
