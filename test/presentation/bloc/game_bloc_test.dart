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

GameBloc _makeBloc(
  Board board, {
  Difficulty difficulty = Difficulty.tutorial,
  Board? solution,
  bool isInfiniteMode = false,
}) =>
    GameBloc(
      puzzle: Puzzle(
        id: 0,
        size: board.size,
        difficulty: difficulty,
        initialBoard: board,
        solution: solution ?? board,
      ),
      gravity: GravityEngine(),
      validator: SudokuValidator(),
      hint: HintService(gravity: GravityEngine(), validator: SudokuValidator()),
      audio: _FakeAudio(),
      isInfiniteMode: isInfiniteMode,
    );

void main() {
  group('GameBloc', () {
    late Board emptyBoard;
    setUp(() => emptyBoard = Board.empty(4));

    blocTest<GameBloc, GameState>(
      'SelectSymbol sets selectedSymbol',
      build: () => _makeBloc(emptyBoard),
      act: (bloc) => bloc.add(const SelectSymbol('3')),
      expect: () => [
        isA<GameState>().having((s) => s.selectedSymbol, 'symbol', '3'),
      ],
    );

    blocTest<GameBloc, GameState>(
      'PlaceNumber with no symbol does nothing',
      build: () => _makeBloc(emptyBoard),
      act: (bloc) => bloc.add(const PlaceNumber(0, 0)),
      expect: () => [],
    );

    blocTest<GameBloc, GameState>(
      'PlaceNumber applies gravity — number lands at bottom',
      build: () => _makeBloc(emptyBoard),
      act: (bloc) => bloc
        ..add(const SelectSymbol('2'))
        ..add(const PlaceNumber(0, 0)),
      verify: (bloc) {
        expect(bloc.state.board.cellAt(3, 0).value, 2);
        expect(bloc.state.board.cellAt(0, 0).isEmpty, isTrue);
      },
    );

    blocTest<GameBloc, GameState>(
      'UndoMove restores previous board',
      build: () => _makeBloc(emptyBoard),
      act: (bloc) => bloc
        ..add(const SelectSymbol('1'))
        ..add(const PlaceNumber(0, 0))
        ..add(const UndoMove()),
      verify: (bloc) {
        expect(bloc.state.board.cellAt(3, 0).isEmpty, isTrue);
      },
    );

    blocTest<GameBloc, GameState>(
      'RestartPuzzle restores initial board and clears moveCount',
      build: () => _makeBloc(emptyBoard),
      act: (bloc) => bloc
        ..add(const SelectSymbol('1'))
        ..add(const PlaceNumber(0, 0))
        ..add(const RestartPuzzle()),
      verify: (bloc) {
        expect(bloc.state.board.cellAt(3, 0).isEmpty, isTrue);
        expect(bloc.state.moveCount, 0);
      },
    );

    blocTest<GameBloc, GameState>(
      'PlaceNumber sets lastPlacedCell and lastPlacedValue on correct move',
      build: () => _makeBloc(emptyBoard),
      act: (bloc) => bloc
        ..add(const SelectSymbol('1'))
        ..add(const PlaceNumber(0, 0)),
      verify: (bloc) {
        // Tutorial mode: every placement is "correct" (solution == initialBoard)
        // Number falls to bottom row (row 3 in a 4x4 board)
        expect(bloc.state.lastPlacedCell, const Position(3, 0));
        expect(bloc.state.lastPlacedValue, 1);
      },
    );

    blocTest<GameBloc, GameState>(
      'ClearFallingAnimation clears lastPlacedCell and lastPlacedValue',
      build: () => _makeBloc(emptyBoard),
      act: (bloc) => bloc
        ..add(const SelectSymbol('1'))
        ..add(const PlaceNumber(0, 0))
        ..add(const ClearFallingAnimation()),
      verify: (bloc) {
        expect(bloc.state.lastPlacedCell, isNull);
        expect(bloc.state.lastPlacedValue, isNull);
      },
    );

    blocTest<GameBloc, GameState>(
      'IceBlockAnimationComplete moves position to permanentlyUnlocked',
      build: () => _makeBloc(emptyBoard),
      seed: () => GameState.initial(emptyBoard, isTutorial: true).copyWith(
        unlockedIceBlocks: const [Position(2, 2)],
      ),
      act: (bloc) => bloc.add(const IceBlockAnimationComplete(2, 2)),
      verify: (bloc) {
        expect(bloc.state.unlockedIceBlocks, isEmpty);
        expect(bloc.state.permanentlyUnlocked, contains(const Position(2, 2)));
      },
    );

    test('GameState initial has empty notes, isPencilMode=false, isInfiniteMode=false', () {
      final state = GameState.initial(Board.empty(4), isTutorial: false);
      expect(state.notes, isEmpty);
      expect(state.isPencilMode, isFalse);
      expect(state.isInfiniteMode, isFalse);
    });

    test('isInfiniteMode=true is stored in initial state', () {
      final bloc = _makeBloc(
        Board.empty(4),
        difficulty: Difficulty.easy,
        isInfiniteMode: true,
      );
      expect(bloc.state.isInfiniteMode, isTrue);
      bloc.close();
    });

    blocTest<GameBloc, GameState>(
      'SelectNoteSymbol sets isPencilMode=true and selectedSymbol',
      build: () => _makeBloc(Board.empty(4)),
      act: (bloc) => bloc.add(const SelectNoteSymbol('3')),
      verify: (bloc) {
        expect(bloc.state.isPencilMode, isTrue);
        expect(bloc.state.selectedSymbol, '3');
      },
    );

    blocTest<GameBloc, GameState>(
      'SelectSymbol resets isPencilMode to false',
      build: () => _makeBloc(Board.empty(4)),
      act: (bloc) => bloc
        ..add(const SelectNoteSymbol('3'))
        ..add(const SelectSymbol('2')),
      verify: (bloc) {
        expect(bloc.state.isPencilMode, isFalse);
        expect(bloc.state.selectedSymbol, '2');
      },
    );

    blocTest<GameBloc, GameState>(
      'ToggleNote adds note value to an empty cell',
      build: () => _makeBloc(Board.empty(4)),
      act: (bloc) => bloc
        ..add(const SelectNoteSymbol('2'))
        ..add(const ToggleNote(0, 1)),
      verify: (bloc) {
        expect(bloc.state.notes[const Position(0, 1)], contains(2));
      },
    );

    blocTest<GameBloc, GameState>(
      'ToggleNote removes note when already present',
      build: () => _makeBloc(Board.empty(4)),
      act: (bloc) => bloc
        ..add(const SelectNoteSymbol('2'))
        ..add(const ToggleNote(0, 1))
        ..add(const ToggleNote(0, 1)),
      verify: (bloc) {
        final n = bloc.state.notes[const Position(0, 1)];
        expect(n == null || !n.contains(2), isTrue);
      },
    );

    blocTest<GameBloc, GameState>(
      'ToggleNote does nothing when selectedSymbol is null',
      build: () => _makeBloc(Board.empty(4)),
      act: (bloc) => bloc.add(const ToggleNote(0, 1)),
      verify: (bloc) => expect(bloc.state.notes.isEmpty, isTrue),
    );

    blocTest<GameBloc, GameState>(
      'ToggleNote does nothing when cell already has a value',
      build: () => _makeBloc(Board.empty(4)),
      act: (bloc) => bloc
        ..add(const SelectSymbol('1'))
        ..add(const PlaceNumber(0, 0))   // lands at (3,0) value=1
        ..add(const SelectNoteSymbol('2'))
        ..add(const ToggleNote(3, 0)),   // cell at (3,0) has value
      verify: (bloc) {
        final n = bloc.state.notes[const Position(3, 0)];
        expect(n == null || !n.contains(2), isTrue);
      },
    );

    blocTest<GameBloc, GameState>(
      'ToggleNote does nothing when cell is fixed',
      build: () => _makeBloc(Board(
        size: 4,
        cells: [
          [Cell(), Cell(), Cell(), Cell()],
          [Cell(), Cell(), Cell(), Cell()],
          [Cell(), Cell(), Cell(), Cell()],
          [Cell(value: 1, isFixed: true), Cell(), Cell(), Cell()],
        ],
      )),
      act: (bloc) => bloc
        ..add(const SelectNoteSymbol('2'))
        ..add(const ToggleNote(3, 0)),
      verify: (bloc) {
        final n = bloc.state.notes[const Position(3, 0)];
        expect(n == null || !n.contains(2), isTrue);
      },
    );

    blocTest<GameBloc, GameState>(
      'PlaceNumber auto-clears conflicting notes in same row and column',
      build: () => _makeBloc(Board.empty(4)),
      act: (bloc) => bloc
        ..add(const SelectNoteSymbol('1'))
        ..add(const ToggleNote(3, 1))  // same row as landing position
        ..add(const ToggleNote(2, 0))  // same column as placement column
        ..add(const SelectSymbol('1'))
        ..add(const PlaceNumber(0, 0)), // gravity: falls to (3,0)
      verify: (bloc) {
        final n31 = bloc.state.notes[const Position(3, 1)];
        final n20 = bloc.state.notes[const Position(2, 0)];
        expect(n31 == null || !n31.contains(1), isTrue);
        expect(n20 == null || !n20.contains(1), isTrue);
      },
    );

    blocTest<GameBloc, GameState>(
      'PlaceNumber auto-clears notes in same box (different row and column)',
      build: () => _makeBloc(Board.empty(4)),
      act: (bloc) => bloc
        ..add(const SelectNoteSymbol('1'))
        ..add(const ToggleNote(2, 1))  // same 2x2 box as (3,0), different row AND col
        ..add(const SelectSymbol('1'))
        ..add(const PlaceNumber(0, 0)), // gravity: falls to (3,0)
      verify: (bloc) {
        // (2,1) is in the box covering rows 2-3, cols 0-1 (same box as (3,0))
        final n = bloc.state.notes[const Position(2, 1)];
        expect(n == null || !n.contains(1), isTrue);
      },
    );

    test('UndoMove preserves current isPencilMode (not restored from snapshot)', () async {
      final bloc = _makeBloc(Board.empty(4));
      bloc.add(const SelectNoteSymbol('1')); // enter pencil mode
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isPencilMode, isTrue);

      // Undo (even with empty stack, isPencilMode should not change)
      bloc.add(const UndoMove());
      await Future<void>.delayed(Duration.zero);
      // Stack is empty so undo does nothing, but isPencilMode must remain as-is
      expect(bloc.state.isPencilMode, isTrue);
      await bloc.close();
    });

    test('RestartPuzzle preserves isInfiniteMode', () async {
      final bloc = _makeBloc(Board.empty(4), isInfiniteMode: true);
      expect(bloc.state.isInfiniteMode, isTrue);
      bloc.add(const RestartPuzzle());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isInfiniteMode, isTrue);
      await bloc.close();
    });

    blocTest<GameBloc, GameState>(
      'PlaceNumber does not deduct hearts when isInfiniteMode=true and answer is wrong',
      build: () {
        // solution has value 2 at (3,0); placing '1' is wrong
        final solution = Board(
          size: 4,
          cells: [
            [Cell(value: 2), Cell(value: 1), Cell(value: 4), Cell(value: 3)],
            [Cell(value: 4), Cell(value: 3), Cell(value: 2), Cell(value: 1)],
            [Cell(value: 3), Cell(value: 4), Cell(value: 1), Cell(value: 2)],
            [Cell(value: 2), Cell(value: 1), Cell(value: 3), Cell(value: 4)],
          ],
        );
        return _makeBloc(
          Board.empty(4),
          difficulty: Difficulty.easy,
          solution: solution,
          isInfiniteMode: true,
        );
      },
      act: (bloc) => bloc
        ..add(const SelectSymbol('1'))
        ..add(const PlaceNumber(0, 0)), // falls to (3,0); solution there is 2 → wrong
      verify: (bloc) {
        expect(bloc.state.hearts, 3); // no deduction
        expect(bloc.state.status, GameStatus.playing);
      },
    );
  });
}
