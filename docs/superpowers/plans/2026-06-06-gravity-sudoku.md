# Gravity Sudoku Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter mobile puzzle game combining Sudoku logic with downward gravity mechanics, supporting 4×4 / 9×9 / 12×12 / 16×16 / 32×32 boards, runnable on Android and as a web preview.

**Architecture:** Clean Architecture — pure-Dart domain layer (game engine, validator), drift SQLite data layer, flutter_bloc presentation layer. Domain has zero Flutter dependency and is fully unit-testable.

**Tech Stack:** Flutter 3, flutter_bloc ^8, drift ^2, shared_preferences, google_fonts, confetti, audioplayers, google_mobile_ads.

> **Spec correction (gravity input):** The spec note "row doesn't matter, only column" is wrong. The player taps a specific cell (row, col); the number falls FROM that row downward. Ice blocks divide each column into independent gravity zones, so the chosen row determines which zone is targeted. This is the correct and richer mechanic.

---

## File Map

```
D:\projects\gravity-sudoku\
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/board_sizes.dart
│   │   ├── constants/symbols.dart
│   │   ├── theme/app_colors.dart
│   │   ├── theme/app_theme.dart
│   │   └── utils/position.dart
│   ├── domain/
│   │   ├── models/cell.dart
│   │   ├── models/board.dart
│   │   ├── models/gravity_result.dart
│   │   ├── models/puzzle.dart
│   │   ├── services/gravity_engine.dart
│   │   ├── services/sudoku_validator.dart
│   │   ├── services/hint_service.dart
│   │   ├── repositories/puzzle_repository.dart
│   │   └── repositories/progress_repository.dart
│   ├── data/
│   │   ├── local/database/app_database.dart
│   │   ├── local/prefs/preferences_service.dart
│   │   ├── repositories/local_puzzle_repository.dart
│   │   └── repositories/local_progress_repository.dart
│   └── presentation/
│       ├── bloc/game/game_bloc.dart
│       ├── bloc/game/game_event.dart
│       ├── bloc/game/game_state.dart
│       ├── bloc/settings/settings_bloc.dart
│       ├── bloc/settings/settings_event.dart
│       ├── bloc/settings/settings_state.dart
│       ├── screens/home/home_screen.dart
│       ├── screens/level_select/level_select_screen.dart
│       ├── screens/game/game_screen.dart
│       ├── screens/completion/completion_screen.dart
│       └── widgets/
│           ├── sudoku_grid.dart
│           ├── cell_tile.dart
│           ├── ice_block_tile.dart
│           ├── number_panel.dart
│           ├── game_controls.dart
│           └── falling_number_overlay.dart
├── test/
│   ├── domain/models/cell_test.dart
│   ├── domain/models/board_test.dart
│   ├── domain/services/gravity_engine_test.dart
│   ├── domain/services/sudoku_validator_test.dart
│   ├── domain/services/hint_service_test.dart
│   └── presentation/bloc/game_bloc_test.dart
└── assets/
    ├── puzzles/easy_4x4.json
    ├── puzzles/normal_9x9.json
    ├── puzzles/hard_12x12.json
    ├── puzzles/expert_16x16.json
    ├── puzzles/extreme_32x32.json
    └── audio/
        ├── click.mp3
        ├── thud.mp3
        ├── ice_clink.mp3
        ├── error.mp3
        └── complete.mp3
```

---

## Task 1: Flutter Project Setup

**Files:**
- Create: `pubspec.yaml`
- Create: `assets/` directory structure

- [ ] **Step 1: Create Flutter project inside existing directory**

```powershell
cd D:\projects\gravity-sudoku
flutter create . --project-name gravity_sudoku --org com.invisibleyou
```

Expected: Flutter project scaffolded. `lib/main.dart` created.

- [ ] **Step 2: Replace pubspec.yaml**

```yaml
name: gravity_sudoku
description: Gravity Sudoku — Sudoku meets gravity mechanics.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.3
  path: ^1.9.0
  shared_preferences: ^2.3.0
  google_fonts: ^6.2.1
  confetti: ^0.7.0
  audioplayers: ^6.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  drift_dev: ^2.18.0
  build_runner: ^2.4.12
  bloc_test: ^9.1.7
  mocktail: ^1.0.4

flutter:
  uses-material-design: true
  assets:
    - assets/puzzles/
    - assets/audio/
```

- [ ] **Step 3: Create asset directories**

```powershell
New-Item -ItemType Directory -Force assets/puzzles
New-Item -ItemType Directory -Force assets/audio
```

- [ ] **Step 4: Install dependencies**

```powershell
flutter pub get
```

Expected: No errors. `pubspec.lock` created.

- [ ] **Step 5: Create lib subdirectories**

```powershell
@('core/constants','core/theme','core/utils',
  'domain/models','domain/services','domain/repositories',
  'data/local/database','data/local/prefs','data/repositories',
  'presentation/bloc/game','presentation/bloc/settings',
  'presentation/screens/home','presentation/screens/level_select',
  'presentation/screens/game','presentation/screens/completion',
  'presentation/widgets') | ForEach-Object {
  New-Item -ItemType Directory -Force "lib/$_"
}
@('domain/models','domain/services','presentation/bloc') | ForEach-Object {
  New-Item -ItemType Directory -Force "test/$_"
}
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter project"
```

---

## Task 2: Core Constants & Utilities

**Files:**
- Create: `lib/core/constants/board_sizes.dart`
- Create: `lib/core/constants/symbols.dart`
- Create: `lib/core/utils/position.dart`

- [ ] **Step 1: Write board_sizes.dart**

```dart
// lib/core/constants/board_sizes.dart
enum BoardSize {
  s4(4, 2, 2),
  s9(9, 3, 3),
  s12(12, 3, 4),
  s16(16, 4, 4),
  s32(32, 4, 8);

  final int n;
  final int subRows;
  final int subCols;
  const BoardSize(this.n, this.subRows, this.subCols);

  static BoardSize fromInt(int n) =>
      values.firstWhere((s) => s.n == n);
}
```

- [ ] **Step 2: Write symbols.dart**

```dart
// lib/core/constants/symbols.dart
class SymbolSystem {
  static const Map<int, List<String>> _symbols = {
    4:  ['1','2','3','4'],
    9:  ['1','2','3','4','5','6','7','8','9'],
    12: ['1','2','3','4','5','6','7','8','9','A','B','C'],
    16: ['1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G'],
    32: ['1','2','3','4','5','6','7','8','9',
         'A','B','C','D','E','F','G','H','I','J','K','L','M',
         'N','O','P','Q','R','S','T','U','V','W'],
  };

  static List<String> forSize(int n) => _symbols[n]!;

  static int toValue(String s) {
    final parsed = int.tryParse(s);
    if (parsed != null) return parsed;
    return s.codeUnitAt(0) - 'A'.codeUnitAt(0) + 10;
  }

  static String fromValue(int v) {
    if (v <= 9) return v.toString();
    return String.fromCharCode('A'.codeUnitAt(0) + v - 10);
  }
}
```

- [ ] **Step 3: Write position.dart**

```dart
// lib/core/utils/position.dart
import 'package:equatable/equatable.dart';

class Position extends Equatable {
  final int row;
  final int col;
  const Position(this.row, this.col);

  @override
  List<Object> get props => [row, col];

  @override
  String toString() => '($row,$col)';
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/core
git commit -m "feat: add core constants and Position"
```

---

## Task 3: Cell Model (TDD)

**Files:**
- Create: `lib/domain/models/cell.dart`
- Create: `test/domain/models/cell_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/domain/models/cell_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';

void main() {
  group('Cell', () {
    test('default cell is empty', () {
      const c = Cell();
      expect(c.isEmpty, isTrue);
      expect(c.hasNumber, isFalse);
      expect(c.isIceBlock, isFalse);
    });

    test('cell with value is not empty', () {
      const c = Cell(value: 3);
      expect(c.isEmpty, isFalse);
      expect(c.hasNumber, isTrue);
    });

    test('ice block cell is not empty', () {
      const c = Cell(isIceBlock: true);
      expect(c.isEmpty, isFalse);
      expect(c.hasNumber, isFalse);
    });

    test('copyWith replaces only specified fields', () {
      const c = Cell(value: 5, isFixed: true);
      final c2 = c.copyWith(value: 7);
      expect(c2.value, 7);
      expect(c2.isFixed, isTrue);
    });

    test('cleared removes value and fixed flag', () {
      const c = Cell(value: 3, isFixed: false);
      final c2 = c.cleared();
      expect(c2.value, isNull);
      expect(c2.isFixed, isFalse);
    });

    test('equality by value', () {
      expect(const Cell(value: 1), equals(const Cell(value: 1)));
      expect(const Cell(value: 1), isNot(equals(const Cell(value: 2))));
    });
  });
}
```

- [ ] **Step 2: Run test — expect failure**

```bash
flutter test test/domain/models/cell_test.dart
```

Expected: FAIL — `cell.dart` not found.

- [ ] **Step 3: Implement cell.dart**

```dart
// lib/domain/models/cell.dart
import 'package:equatable/equatable.dart';

class Cell extends Equatable {
  final int? value;
  final bool isFixed;
  final bool isIceBlock;

  const Cell({this.value, this.isFixed = false, this.isIceBlock = false});

  bool get isEmpty => value == null && !isIceBlock;
  bool get hasNumber => value != null;

  Cell copyWith({int? value, bool? isFixed, bool? isIceBlock}) => Cell(
        value: value ?? this.value,
        isFixed: isFixed ?? this.isFixed,
        isIceBlock: isIceBlock ?? this.isIceBlock,
      );

  Cell cleared() => const Cell();

  @override
  List<Object?> get props => [value, isFixed, isIceBlock];
}
```

- [ ] **Step 4: Run test — expect pass**

```bash
flutter test test/domain/models/cell_test.dart
```

Expected: All 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/cell.dart test/domain/models/cell_test.dart
git commit -m "feat: add Cell model"
```

---

## Task 4: Board Model (TDD)

**Files:**
- Create: `lib/domain/models/board.dart`
- Create: `test/domain/models/board_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/domain/models/board_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';

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
      expect(b.cellAt(1, 2).isEmpty, isTrue); // original unchanged
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
}
```

- [ ] **Step 2: Run test — expect failure**

```bash
flutter test test/domain/models/board_test.dart
```

- [ ] **Step 3: Implement board.dart**

```dart
// lib/domain/models/board.dart
import 'cell.dart';

class Board {
  final int size;
  final List<List<Cell>> cells;

  Board({required this.size, required this.cells});

  factory Board.empty(int size) => Board(
        size: size,
        cells: List.generate(
          size,
          (_) => List.generate(size, (_) => const Cell()),
        ),
      );

  Cell cellAt(int row, int col) => cells[row][col];

  Board setCell(int row, int col, Cell cell) {
    final next = cells.map((r) => [...r]).toList();
    next[row][col] = cell;
    return Board(size: size, cells: next);
  }

  bool get isComplete => cells.every(
        (row) => row.every((c) => c.isIceBlock || c.hasNumber),
      );
}
```

- [ ] **Step 4: Run test — expect pass**

```bash
flutter test test/domain/models/board_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/board.dart test/domain/models/board_test.dart
git commit -m "feat: add Board model"
```

---

## Task 5: GravityResult Model

**Files:**
- Create: `lib/domain/models/gravity_result.dart`

- [ ] **Step 1: Write gravity_result.dart**

```dart
// lib/domain/models/gravity_result.dart
import 'package:equatable/equatable.dart';

class GravityResult extends Equatable {
  final int col;
  final int fromRow;
  final int toRow;

  const GravityResult({
    required this.col,
    required this.fromRow,
    required this.toRow,
  });

  bool get moved => fromRow != toRow;

  @override
  List<Object> get props => [col, fromRow, toRow];
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/domain/models/gravity_result.dart
git commit -m "feat: add GravityResult model"
```

---

## Task 6: Gravity Engine (TDD)

**Files:**
- Create: `lib/domain/services/gravity_engine.dart`
- Create: `test/domain/services/gravity_engine_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/domain/services/gravity_engine_test.dart
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
      // placing at row 2 — below the ice block
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
```

- [ ] **Step 2: Run test — expect failure**

```bash
flutter test test/domain/services/gravity_engine_test.dart
```

- [ ] **Step 3: Implement gravity_engine.dart**

```dart
// lib/domain/services/gravity_engine.dart
import '../models/board.dart';
import '../models/cell.dart';
import '../models/gravity_result.dart';

class GravityEngine {
  GravityResult simulate(Board board, {required int col, required int fromRow}) {
    int toRow = fromRow;
    for (int r = fromRow + 1; r < board.size; r++) {
      final cell = board.cellAt(r, col);
      if (cell.isIceBlock || cell.hasNumber) break;
      toRow = r;
    }
    return GravityResult(col: col, fromRow: fromRow, toRow: toRow);
  }

  Board apply(Board board, {required int col, required int value, required GravityResult result}) {
    return board.setCell(result.toRow, col, Cell(value: value));
  }
}
```

- [ ] **Step 4: Run test — expect pass**

```bash
flutter test test/domain/services/gravity_engine_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/gravity_engine.dart test/domain/services/gravity_engine_test.dart
git commit -m "feat: add GravityEngine"
```

---

## Task 7: Sudoku Validator (TDD)

**Files:**
- Create: `lib/domain/services/sudoku_validator.dart`
- Create: `test/domain/services/sudoku_validator_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/domain/services/sudoku_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/core/constants/board_sizes.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';
import 'package:gravity_sudoku/domain/services/sudoku_validator.dart';

Board _makeBoard(List<List<int>> grid) {
  // 0 = empty, -1 = ice
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
```

- [ ] **Step 2: Run — expect failure**

```bash
flutter test test/domain/services/sudoku_validator_test.dart
```

- [ ] **Step 3: Implement sudoku_validator.dart**

```dart
// lib/domain/services/sudoku_validator.dart
import '../models/board.dart';

class SudokuValidator {
  List<(int, int)> findConflicts(Board board) {
    final conflicts = <(int, int)>{};
    final size = board.size;
    final sub = _subgrid(size);

    // Rows
    for (var r = 0; r < size; r++) {
      final seen = <int, List<int>>{};
      for (var c = 0; c < size; c++) {
        final v = board.cellAt(r, c).value;
        if (v != null) seen.putIfAbsent(v, () => []).add(c);
      }
      for (final cols in seen.values) {
        if (cols.length > 1) {
          for (final c in cols) conflicts.add((r, c));
        }
      }
    }

    // Columns
    for (var c = 0; c < size; c++) {
      final seen = <int, List<int>>{};
      for (var r = 0; r < size; r++) {
        final v = board.cellAt(r, c).value;
        if (v != null) seen.putIfAbsent(v, () => []).add(r);
      }
      for (final rows in seen.values) {
        if (rows.length > 1) {
          for (final r in rows) conflicts.add((r, c));
        }
      }
    }

    // Subgrids
    final (sr, sc) = sub;
    for (var br = 0; br < size; br += sr) {
      for (var bc = 0; bc < size; bc += sc) {
        final seen = <int, List<(int, int)>>{};
        for (var r = br; r < br + sr; r++) {
          for (var c = bc; c < bc + sc; c++) {
            final v = board.cellAt(r, c).value;
            if (v != null) seen.putIfAbsent(v, () => []).add((r, c));
          }
        }
        for (final positions in seen.values) {
          if (positions.length > 1) conflicts.addAll(positions);
        }
      }
    }

    return conflicts.toList();
  }

  bool isValid(Board board) => findConflicts(board).isEmpty;

  bool isComplete(Board board) {
    if (!isValid(board)) return false;
    return board.isComplete;
  }

  (int, int) _subgrid(int size) => switch (size) {
        4 => (2, 2),
        9 => (3, 3),
        12 => (3, 4),
        16 => (4, 4),
        32 => (4, 8),
        _ => throw ArgumentError('Unsupported board size: $size'),
      };
}
```

- [ ] **Step 4: Run — expect pass**

```bash
flutter test test/domain/services/sudoku_validator_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/sudoku_validator.dart test/domain/services/sudoku_validator_test.dart
git commit -m "feat: add SudokuValidator"
```

---

## Task 8: Hint Service (TDD)

**Files:**
- Create: `lib/domain/services/hint_service.dart`
- Create: `test/domain/services/hint_service_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/domain/services/hint_service_test.dart
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
    // fill board fully
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
    // Board with 3 numbers in col 0, 1 missing
    var b = Board.empty(4);
    b = b.setCell(1, 0, const Cell(value: 2));
    b = b.setCell(2, 0, const Cell(value: 3));
    b = b.setCell(3, 0, const Cell(value: 4));
    // Col 0 row 0 needs value 1
    final hint = hints.suggest(b, boardSize: 4);
    expect(hint, isNotNull);
    expect(hint!.col, 0);
    expect(hint.row, 0);
  });
}
```

- [ ] **Step 2: Run — expect failure**

```bash
flutter test test/domain/services/hint_service_test.dart
```

- [ ] **Step 3: Implement hint_service.dart**

```dart
// lib/domain/services/hint_service.dart
import '../../core/constants/symbols.dart';
import '../models/board.dart';
import 'gravity_engine.dart';
import 'sudoku_validator.dart';

class HintMove {
  final int row;
  final int col;
  final String symbol;
  const HintMove({required this.row, required this.col, required this.symbol});
}

class HintService {
  final GravityEngine _gravity;
  final SudokuValidator _validator;

  HintService({required GravityEngine gravity, required SudokuValidator validator})
      : _gravity = gravity,
        _validator = validator;

  HintMove? suggest(Board board, {required int boardSize}) {
    final symbols = SymbolSystem.forSize(boardSize);
    for (var r = 0; r < board.size; r++) {
      for (var c = 0; c < board.size; c++) {
        if (!board.cellAt(r, c).isEmpty) continue;
        for (final sym in symbols) {
          final value = SymbolSystem.toValue(sym);
          final result = _gravity.simulate(board, col: c, fromRow: r);
          // Skip if gravity would land on a non-empty cell
          if (!board.cellAt(result.toRow, c).isEmpty) continue;
          final trial = _gravity.apply(board, col: c, value: value, result: result);
          if (_validator.isValid(trial)) {
            return HintMove(row: r, col: c, symbol: sym);
          }
        }
      }
    }
    return null;
  }
}
```

- [ ] **Step 4: Run — expect pass**

```bash
flutter test test/domain/services/hint_service_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/hint_service.dart test/domain/services/hint_service_test.dart
git commit -m "feat: add HintService"
```

---

## Task 9: Puzzle Model & Repository Interfaces

**Files:**
- Create: `lib/domain/models/puzzle.dart`
- Create: `lib/domain/repositories/puzzle_repository.dart`
- Create: `lib/domain/repositories/progress_repository.dart`

- [ ] **Step 1: Write puzzle.dart**

```dart
// lib/domain/models/puzzle.dart
import 'board.dart';

enum Difficulty { easy, normal, hard, expert, extreme, daily }

class Puzzle {
  final int id;
  final int size;
  final Difficulty difficulty;
  final Board initialBoard;
  final Board solution;

  const Puzzle({
    required this.id,
    required this.size,
    required this.difficulty,
    required this.initialBoard,
    required this.solution,
  });
}
```

- [ ] **Step 2: Write puzzle_repository.dart**

```dart
// lib/domain/repositories/puzzle_repository.dart
import '../models/puzzle.dart';

abstract class PuzzleRepository {
  Future<List<Puzzle>> fetchByDifficulty(Difficulty difficulty);
  Future<Puzzle?> fetchById(int id);
  Future<Puzzle?> fetchDaily();
}
```

- [ ] **Step 3: Write progress_repository.dart**

```dart
// lib/domain/repositories/progress_repository.dart
import '../models/board.dart';

class PuzzleProgress {
  final int puzzleId;
  final Board currentBoard;
  final List<Board> undoStack;
  final int elapsedSeconds;
  final int hintUsedCount;
  final bool isCompleted;

  const PuzzleProgress({
    required this.puzzleId,
    required this.currentBoard,
    required this.undoStack,
    required this.elapsedSeconds,
    required this.hintUsedCount,
    required this.isCompleted,
  });
}

abstract class ProgressRepository {
  Future<PuzzleProgress?> load(int puzzleId);
  Future<void> save(PuzzleProgress progress);
  Future<void> markComplete(int puzzleId);
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/domain/models/puzzle.dart lib/domain/repositories/
git commit -m "feat: add Puzzle model and repository interfaces"
```

---

## Task 10: Sample Puzzle JSON Data

**Files:**
- Create: `assets/puzzles/easy_4x4.json`
- Create: `assets/puzzles/normal_9x9.json`

- [ ] **Step 1: Write easy_4x4.json**

```json
{
  "puzzles": [
    {
      "id": 1,
      "size": 4,
      "difficulty": "easy",
      "initial": [
        [1, 0, 0, 2],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [3, 0, 0, 4]
      ],
      "ice_blocks": [],
      "solution": [
        [1, 3, 4, 2],
        [4, 2, 3, 1],
        [2, 4, 1, 3],
        [3, 1, 2, 4]
      ],
      "fixed_positions": [[0,0],[0,3],[3,0],[3,3]]
    },
    {
      "id": 2,
      "size": 4,
      "difficulty": "easy",
      "initial": [
        [0, 1, 0, 0],
        [0, 0, 0, 3],
        [2, 0, 0, 0],
        [0, 0, 4, 0]
      ],
      "ice_blocks": [[1, 1]],
      "solution": [
        [4, 1, 3, 2],
        [1, -1, 2, 3],
        [2, 3, 1, 4],
        [3, 2, 4, 1]
      ],
      "fixed_positions": [[0,1],[1,3],[2,0],[3,2]]
    }
  ]
}
```

- [ ] **Step 2: Write normal_9x9.json**

```json
{
  "puzzles": [
    {
      "id": 101,
      "size": 9,
      "difficulty": "normal",
      "initial": [
        [5,3,0, 0,7,0, 0,0,0],
        [6,0,0, 1,9,5, 0,0,0],
        [0,9,8, 0,0,0, 0,6,0],

        [8,0,0, 0,6,0, 0,0,3],
        [4,0,0, 8,0,3, 0,0,1],
        [7,0,0, 0,2,0, 0,0,6],

        [0,6,0, 0,0,0, 2,8,0],
        [0,0,0, 4,1,9, 0,0,5],
        [0,0,0, 0,8,0, 0,7,9]
      ],
      "ice_blocks": [],
      "solution": [
        [5,3,4, 6,7,8, 9,1,2],
        [6,7,2, 1,9,5, 3,4,8],
        [1,9,8, 3,4,2, 5,6,7],

        [8,5,9, 7,6,1, 4,2,3],
        [4,2,6, 8,5,3, 7,9,1],
        [7,1,3, 9,2,4, 8,5,6],

        [9,6,1, 5,3,7, 2,8,4],
        [2,8,7, 4,1,9, 6,3,5],
        [3,4,5, 2,8,6, 1,7,9]
      ],
      "fixed_positions": [
        [0,0],[0,1],[0,4],
        [1,0],[1,3],[1,4],[1,5],
        [2,1],[2,2],[2,7],
        [3,0],[3,4],[3,8],
        [4,0],[4,3],[4,5],[4,8],
        [5,0],[5,4],[5,8],
        [6,1],[6,6],[6,7],
        [7,3],[7,4],[7,5],[7,8],
        [8,4],[8,7],[8,8]
      ]
    }
  ]
}
```

- [ ] **Step 3: Create placeholder files for other sizes**

```powershell
'{"puzzles":[]}' | Out-File -Encoding utf8 assets/puzzles/hard_12x12.json
'{"puzzles":[]}' | Out-File -Encoding utf8 assets/puzzles/expert_16x16.json
'{"puzzles":[]}' | Out-File -Encoding utf8 assets/puzzles/extreme_32x32.json
```

- [ ] **Step 4: Commit**

```bash
git add assets/puzzles/
git commit -m "feat: add sample puzzle JSON data"
```

---

## Task 11: Database & Repository (drift)

**Files:**
- Create: `lib/data/local/database/app_database.dart`
- Create: `lib/data/repositories/local_puzzle_repository.dart`
- Create: `lib/data/repositories/local_progress_repository.dart`

- [ ] **Step 1: Write app_database.dart**

```dart
// lib/data/local/database/app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Puzzles extends Table {
  IntColumn get id => integer()();
  IntColumn get size => integer()();
  TextColumn get difficulty => text()();
  TextColumn get boardJson => text()();
  TextColumn get solutionJson => text()();
  TextColumn get iceBlocksJson => text()();
  TextColumn get fixedPositionsJson => text()();
}

class Progresses extends Table {
  IntColumn get puzzleId => integer()();
  TextColumn get boardJson => text()();
  TextColumn get undoStackJson => text()();
  IntColumn get elapsedSeconds => integer()();
  IntColumn get hintUsedCount => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Puzzles, Progresses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'gravity_sudoku.db'));
    return NativeDatabase.createInBackground(file);
  });
}
```

- [ ] **Step 2: Run code generation**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: `app_database.g.dart` created.

- [ ] **Step 3: Write local_puzzle_repository.dart**

```dart
// lib/data/repositories/local_puzzle_repository.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/models/board.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/puzzle.dart';
import '../../domain/repositories/puzzle_repository.dart';
import '../local/database/app_database.dart';

class LocalPuzzleRepository implements PuzzleRepository {
  final AppDatabase _db;
  LocalPuzzleRepository(this._db);

  @override
  Future<List<Puzzle>> fetchByDifficulty(Difficulty difficulty) async {
    final rows = await (_db.select(_db.puzzles)
          ..where((t) => t.difficulty.equals(difficulty.name)))
        .get();
    return rows.map(_rowToPuzzle).toList();
  }

  @override
  Future<Puzzle?> fetchById(int id) async {
    final row = await (_db.select(_db.puzzles)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _rowToPuzzle(row);
  }

  @override
  Future<Puzzle?> fetchDaily() async {
    final row = await (_db.select(_db.puzzles)
          ..where((t) => t.difficulty.equals('daily'))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _rowToPuzzle(row);
  }

  Future<void> insertFromJson(Map<String, dynamic> json) async {
    final puzzle = json;
    await _db.into(_db.puzzles).insertOnConflictUpdate(PuzzlesCompanion(
      id: Value(puzzle['id'] as int),
      size: Value(puzzle['size'] as int),
      difficulty: Value(puzzle['difficulty'] as String),
      boardJson: Value(jsonEncode(puzzle['initial'])),
      solutionJson: Value(jsonEncode(puzzle['solution'])),
      iceBlocksJson: Value(jsonEncode(puzzle['ice_blocks'] ?? [])),
      fixedPositionsJson: Value(jsonEncode(puzzle['fixed_positions'] ?? [])),
    ));
  }

  Puzzle _rowToPuzzle(Puzzle row) => throw UnimplementedError('see below');
}
```

> Note: Replace the `_rowToPuzzle` stub with the full implementation below.

```dart
  Puzzle _rowToPuzzle(dynamic row) {
    final size = row.size as int;
    final initial = (jsonDecode(row.boardJson) as List)
        .asMap()
        .entries
        .map((rEntry) => (rEntry.value as List)
            .asMap()
            .entries
            .map((cEntry) {
              final v = cEntry.value as int;
              if (v == -1) return const Cell(isIceBlock: true);
              if (v == 0) return const Cell();
              return Cell(value: v, isFixed: true);
            })
            .toList())
        .toList();

    final fixedRaw = jsonDecode(row.fixedPositionsJson) as List;
    final fixedSet = fixedRaw.map((p) => '${p[0]},${p[1]}').toSet();
    // Override isFixed from fixedPositionsJson
    final correctedInitial = initial.asMap().entries.map((rEntry) =>
        rEntry.value.asMap().entries.map((cEntry) {
          final cell = cEntry.value;
          if (fixedSet.contains('${rEntry.key},${cEntry.key}') && cell.hasNumber) {
            return cell.copyWith(isFixed: true);
          }
          return cell;
        }).toList()).toList();

    final sol = (jsonDecode(row.solutionJson) as List)
        .map((r) => (r as List)
            .map((v) => v == -1
                ? const Cell(isIceBlock: true)
                : Cell(value: v as int))
            .toList())
        .toList();

    return Puzzle(
      id: row.id as int,
      size: size,
      difficulty: Difficulty.values.byName(row.difficulty as String),
      initialBoard: Board(size: size, cells: correctedInitial),
      solution: Board(size: size, cells: sol),
    );
  }
```

- [ ] **Step 4: Write local_progress_repository.dart**

```dart
// lib/data/repositories/local_progress_repository.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/models/board.dart';
import '../../domain/models/cell.dart';
import '../../domain/repositories/progress_repository.dart';
import '../local/database/app_database.dart';

class LocalProgressRepository implements ProgressRepository {
  final AppDatabase _db;
  LocalProgressRepository(this._db);

  @override
  Future<PuzzleProgress?> load(int puzzleId) async {
    final row = await (_db.select(_db.progresses)
          ..where((t) => t.puzzleId.equals(puzzleId)))
        .getSingleOrNull();
    if (row == null) return null;
    return PuzzleProgress(
      puzzleId: puzzleId,
      currentBoard: _decodeBoard(row.boardJson),
      undoStack: (jsonDecode(row.undoStackJson) as List)
          .map((j) => _decodeBoard(j as String))
          .toList(),
      elapsedSeconds: row.elapsedSeconds,
      hintUsedCount: row.hintUsedCount,
      isCompleted: row.isCompleted,
    );
  }

  @override
  Future<void> save(PuzzleProgress progress) async {
    await _db.into(_db.progresses).insertOnConflictUpdate(ProgressesCompanion(
      puzzleId: Value(progress.puzzleId),
      boardJson: Value(_encodeBoard(progress.currentBoard)),
      undoStackJson: Value(jsonEncode(
          progress.undoStack.map(_encodeBoard).toList())),
      elapsedSeconds: Value(progress.elapsedSeconds),
      hintUsedCount: Value(progress.hintUsedCount),
      isCompleted: Value(progress.isCompleted),
    ));
  }

  @override
  Future<void> markComplete(int puzzleId) async {
    await (_db.update(_db.progresses)
          ..where((t) => t.puzzleId.equals(puzzleId)))
        .write(const ProgressesCompanion(isCompleted: Value(true)));
  }

  String _encodeBoard(Board board) {
    final grid = board.cells
        .map((row) => row.map((c) {
              if (c.isIceBlock) return -1;
              return c.value ?? 0;
            }).toList())
        .toList();
    return jsonEncode({'size': board.size, 'cells': grid});
  }

  Board _decodeBoard(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final size = map['size'] as int;
    final cells = (map['cells'] as List)
        .map((row) => (row as List)
            .map((v) => v == -1
                ? const Cell(isIceBlock: true)
                : v == 0
                    ? const Cell()
                    : Cell(value: v as int))
            .toList())
        .toList();
    return Board(size: size, cells: cells);
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/data/ lib/data/local/database/app_database.g.dart
git commit -m "feat: add drift database and repository implementations"
```

---

## Task 12: Preferences Service

**Files:**
- Create: `lib/data/local/prefs/preferences_service.dart`

- [ ] **Step 1: Write preferences_service.dart**

```dart
// lib/data/local/prefs/preferences_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  final SharedPreferences _prefs;
  PreferencesService(this._prefs);

  static const _themeKey = 'selected_theme';
  static const _sfxKey = 'sfx_enabled';
  static const _musicKey = 'music_enabled';
  static const _lastPuzzleKey = 'last_played_puzzle_id';

  String get selectedTheme => _prefs.getString(_themeKey) ?? 'light';
  bool get sfxEnabled => _prefs.getBool(_sfxKey) ?? true;
  bool get musicEnabled => _prefs.getBool(_musicKey) ?? true;
  int? get lastPlayedPuzzleId => _prefs.getInt(_lastPuzzleKey);

  Future<void> setTheme(String theme) => _prefs.setString(_themeKey, theme);
  Future<void> setSfx(bool v) => _prefs.setBool(_sfxKey, v);
  Future<void> setMusic(bool v) => _prefs.setBool(_musicKey, v);
  Future<void> setLastPuzzle(int id) => _prefs.setInt(_lastPuzzleKey, id);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/data/local/prefs/preferences_service.dart
git commit -m "feat: add PreferencesService"
```

---

## Task 13: GameBloc (TDD)

**Files:**
- Create: `lib/presentation/bloc/game/game_event.dart`
- Create: `lib/presentation/bloc/game/game_state.dart`
- Create: `lib/presentation/bloc/game/game_bloc.dart`
- Create: `test/presentation/bloc/game_bloc_test.dart`

- [ ] **Step 1: Write game_event.dart**

```dart
// lib/presentation/bloc/game/game_event.dart
import 'package:equatable/equatable.dart';

abstract class GameEvent extends Equatable {
  const GameEvent();
  @override
  List<Object?> get props => [];
}

class SelectSymbol extends GameEvent {
  final String symbol;
  const SelectSymbol(this.symbol);
  @override List<Object?> get props => [symbol];
}

class PlaceNumber extends GameEvent {
  final int row;
  final int col;
  const PlaceNumber(this.row, this.col);
  @override List<Object?> get props => [row, col];
}

class UndoMove extends GameEvent {
  const UndoMove();
}

class RestartPuzzle extends GameEvent {
  const RestartPuzzle();
}

class RequestHint extends GameEvent {
  const RequestHint();
}

class PauseGame extends GameEvent {
  const PauseGame();
}

class ResumeGame extends GameEvent {
  const ResumeGame();
}

class TimerTicked extends GameEvent {
  const TimerTicked();
}
```

- [ ] **Step 2: Write game_state.dart**

```dart
// lib/presentation/bloc/game/game_state.dart
import 'package:equatable/equatable.dart';
import '../../../core/utils/position.dart';
import '../../../domain/models/board.dart';
import '../../../domain/models/gravity_result.dart';

enum GameStatus { playing, paused, completed }

class GameState extends Equatable {
  final Board board;
  final Board initialBoard;
  final String? selectedSymbol;
  final List<Board> undoStack;
  final Position? hintCell;
  final GameStatus status;
  final int moveCount;
  final int elapsedSeconds;
  final int hintUsedCount;
  final List<(int, int)> conflicts;
  final GravityResult? lastGravityResult;

  const GameState({
    required this.board,
    required this.initialBoard,
    this.selectedSymbol,
    this.undoStack = const [],
    this.hintCell,
    this.status = GameStatus.playing,
    this.moveCount = 0,
    this.elapsedSeconds = 0,
    this.hintUsedCount = 0,
    this.conflicts = const [],
    this.lastGravityResult,
  });

  factory GameState.initial(Board board) => GameState(
        board: board,
        initialBoard: board,
      );

  GameState copyWith({
    Board? board,
    Board? initialBoard,
    String? selectedSymbol,
    List<Board>? undoStack,
    Position? hintCell,
    GameStatus? status,
    int? moveCount,
    int? elapsedSeconds,
    int? hintUsedCount,
    List<(int, int)>? conflicts,
    GravityResult? lastGravityResult,
    bool clearHint = false,
    bool clearGravityResult = false,
    bool clearSymbol = false,
  }) =>
      GameState(
        board: board ?? this.board,
        initialBoard: initialBoard ?? this.initialBoard,
        selectedSymbol: clearSymbol ? null : (selectedSymbol ?? this.selectedSymbol),
        undoStack: undoStack ?? this.undoStack,
        hintCell: clearHint ? null : (hintCell ?? this.hintCell),
        status: status ?? this.status,
        moveCount: moveCount ?? this.moveCount,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        hintUsedCount: hintUsedCount ?? this.hintUsedCount,
        conflicts: conflicts ?? this.conflicts,
        lastGravityResult: clearGravityResult ? null : (lastGravityResult ?? this.lastGravityResult),
      );

  int get stars {
    if (hintUsedCount == 0) return 3;
    if (hintUsedCount == 1) return 2;
    return 1;
  }

  @override
  List<Object?> get props => [
        board, initialBoard, selectedSymbol, undoStack,
        hintCell, status, moveCount, elapsedSeconds,
        hintUsedCount, conflicts, lastGravityResult,
      ];
}
```

- [ ] **Step 3: Write game_bloc.dart**

```dart
// lib/presentation/bloc/game/game_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/symbols.dart';
import '../../../domain/models/board.dart';
import '../../../domain/services/gravity_engine.dart';
import '../../../domain/services/hint_service.dart';
import '../../../domain/services/sudoku_validator.dart';
import 'game_event.dart';
import 'game_state.dart';

class GameBloc extends Bloc<GameEvent, GameState> {
  final GravityEngine _gravity;
  final SudokuValidator _validator;
  final HintService _hint;
  final int _boardSize;
  Timer? _timer;

  GameBloc({
    required Board initialBoard,
    required GravityEngine gravity,
    required SudokuValidator validator,
    required HintService hint,
    required int boardSize,
  })  : _gravity = gravity,
        _validator = validator,
        _hint = hint,
        _boardSize = boardSize,
        super(GameState.initial(initialBoard)) {
    on<SelectSymbol>(_onSelectSymbol);
    on<PlaceNumber>(_onPlaceNumber);
    on<UndoMove>(_onUndo);
    on<RestartPuzzle>(_onRestart);
    on<RequestHint>(_onHint);
    on<PauseGame>(_onPause);
    on<ResumeGame>(_onResume);
    on<TimerTicked>(_onTick);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == GameStatus.playing) add(const TimerTicked());
    });
  }

  void _onSelectSymbol(SelectSymbol event, Emitter<GameState> emit) {
    emit(state.copyWith(selectedSymbol: event.symbol, clearHint: true));
  }

  void _onPlaceNumber(PlaceNumber event, Emitter<GameState> emit) {
    final sym = state.selectedSymbol;
    if (sym == null) return;
    final cell = state.board.cellAt(event.row, event.col);
    if (cell.isIceBlock || cell.isFixed) return;

    final value = SymbolSystem.toValue(sym);
    final result = _gravity.simulate(state.board, col: event.col, fromRow: event.row);
    final landCell = state.board.cellAt(result.toRow, event.col);
    if (!landCell.isEmpty) return; // landing spot occupied

    final newBoard = _gravity.apply(state.board, col: event.col, value: value, result: result);
    final conflicts = _validator.findConflicts(newBoard);
    final newStack = [...state.undoStack, state.board];
    final isComplete = conflicts.isEmpty && _validator.isComplete(newBoard);

    emit(state.copyWith(
      board: newBoard,
      undoStack: newStack.length > 50 ? newStack.sublist(newStack.length - 50) : newStack,
      conflicts: conflicts,
      lastGravityResult: result,
      moveCount: state.moveCount + 1,
      status: isComplete ? GameStatus.completed : GameStatus.playing,
      clearHint: true,
    ));
  }

  void _onUndo(UndoMove event, Emitter<GameState> emit) {
    if (state.undoStack.isEmpty) return;
    final prev = state.undoStack.last;
    final newStack = state.undoStack.sublist(0, state.undoStack.length - 1);
    emit(state.copyWith(
      board: prev,
      undoStack: newStack,
      conflicts: _validator.findConflicts(prev),
      clearGravityResult: true,
      clearHint: true,
    ));
  }

  void _onRestart(RestartPuzzle event, Emitter<GameState> emit) {
    emit(GameState.initial(state.initialBoard));
  }

  void _onHint(RequestHint event, Emitter<GameState> emit) {
    final move = _hint.suggest(state.board, boardSize: _boardSize);
    if (move == null) return;
    emit(state.copyWith(
      hintCell: Position(move.row, move.col),
      hintUsedCount: state.hintUsedCount + 1,
    ));
  }

  void _onPause(PauseGame event, Emitter<GameState> emit) {
    emit(state.copyWith(status: GameStatus.paused));
  }

  void _onResume(ResumeGame event, Emitter<GameState> emit) {
    emit(state.copyWith(status: GameStatus.playing));
  }

  void _onTick(TimerTicked event, Emitter<GameState> emit) {
    emit(state.copyWith(elapsedSeconds: state.elapsedSeconds + 1));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 4: Write game_bloc_test.dart**

```dart
// test/presentation/bloc/game_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/domain/models/board.dart';
import 'package:gravity_sudoku/domain/models/cell.dart';
import 'package:gravity_sudoku/domain/services/gravity_engine.dart';
import 'package:gravity_sudoku/domain/services/hint_service.dart';
import 'package:gravity_sudoku/domain/services/sudoku_validator.dart';
import 'package:gravity_sudoku/presentation/bloc/game/game_bloc.dart';
import 'package:gravity_sudoku/presentation/bloc/game/game_event.dart';
import 'package:gravity_sudoku/presentation/bloc/game/game_state.dart';

GameBloc _makeBloc(Board board) => GameBloc(
      initialBoard: board,
      gravity: GravityEngine(),
      validator: SudokuValidator(),
      hint: HintService(gravity: GravityEngine(), validator: SudokuValidator()),
      boardSize: board.size,
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
      'PlaceNumber with symbol applies gravity and updates board',
      build: () => _makeBloc(emptyBoard),
      act: (bloc) => bloc
        ..add(const SelectSymbol('2'))
        ..add(const PlaceNumber(0, 0)),
      verify: (bloc) {
        // number should fall to bottom of col 0 (row 3)
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
      'RestartPuzzle restores initial board',
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
  });
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/presentation/bloc/game_bloc_test.dart
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/bloc/game/ test/presentation/bloc/game_bloc_test.dart
git commit -m "feat: add GameBloc with TDD"
```

---

## Task 14: SettingsBloc

**Files:**
- Create: `lib/presentation/bloc/settings/settings_event.dart`
- Create: `lib/presentation/bloc/settings/settings_state.dart`
- Create: `lib/presentation/bloc/settings/settings_bloc.dart`

- [ ] **Step 1: Write settings files**

```dart
// lib/presentation/bloc/settings/settings_event.dart
abstract class SettingsEvent {}
class ToggleSfx extends SettingsEvent {}
class ToggleMusic extends SettingsEvent {}
class ChangeTheme extends SettingsEvent {
  final String theme;
  ChangeTheme(this.theme);
}
```

```dart
// lib/presentation/bloc/settings/settings_state.dart
import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  final bool sfxEnabled;
  final bool musicEnabled;
  final String theme;

  const SettingsState({
    this.sfxEnabled = true,
    this.musicEnabled = true,
    this.theme = 'light',
  });

  SettingsState copyWith({bool? sfxEnabled, bool? musicEnabled, String? theme}) =>
      SettingsState(
        sfxEnabled: sfxEnabled ?? this.sfxEnabled,
        musicEnabled: musicEnabled ?? this.musicEnabled,
        theme: theme ?? this.theme,
      );

  @override
  List<Object> get props => [sfxEnabled, musicEnabled, theme];
}
```

```dart
// lib/presentation/bloc/settings/settings_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/local/prefs/preferences_service.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final PreferencesService _prefs;

  SettingsBloc(this._prefs)
      : super(SettingsState(
          sfxEnabled: _prefs.sfxEnabled,
          musicEnabled: _prefs.musicEnabled,
          theme: _prefs.selectedTheme,
        )) {
    on<ToggleSfx>((e, emit) async {
      final v = !state.sfxEnabled;
      await _prefs.setSfx(v);
      emit(state.copyWith(sfxEnabled: v));
    });
    on<ToggleMusic>((e, emit) async {
      final v = !state.musicEnabled;
      await _prefs.setMusic(v);
      emit(state.copyWith(musicEnabled: v));
    });
    on<ChangeTheme>((e, emit) async {
      await _prefs.setTheme(e.theme);
      emit(state.copyWith(theme: e.theme));
    });
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/bloc/settings/
git commit -m "feat: add SettingsBloc"
```

---

## Task 15: App Theme

**Files:**
- Create: `lib/core/theme/app_colors.dart`
- Create: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: Write app_colors.dart**

```dart
// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF5B8BDF);
  static const accent = Color(0xFF4CD9A0);
  static const iceBlock = Color(0xFFB3E5FC);
  static const iceBlockBorder = Color(0xFF81D4FA);
  static const fixedNumber = Color(0xFF263238);
  static const playerNumber = Color(0xFF5B8BDF);
  static const conflict = Color(0xFFEF5350);
  static const hint = Color(0xFFFFD54F);
  static const gridLine = Color(0xFFE0E0E0);
  static const gridLineBold = Color(0xFF9E9E9E);
  static const text = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);

  // Dark mode
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkGridLine = Color(0xFF333333);
  static const darkGridLineBold = Color(0xFF555555);
  static const darkText = Color(0xFFEEEEEE);
}
```

- [ ] **Step 2: Write app_theme.dart**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.nunitoTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.text,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: AppColors.primary,
          surface: AppColors.darkSurface,
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
        textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBackground,
          elevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.darkText,
        ),
      );
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/theme/
git commit -m "feat: add app theme (light/dark)"
```

---

## Task 16: Core Widgets

**Files:**
- Create: `lib/presentation/widgets/cell_tile.dart`
- Create: `lib/presentation/widgets/ice_block_tile.dart`
- Create: `lib/presentation/widgets/number_panel.dart`
- Create: `lib/presentation/widgets/game_controls.dart`

- [ ] **Step 1: Write cell_tile.dart**

```dart
// lib/presentation/widgets/cell_tile.dart
import 'package:flutter/material.dart';
import '../../core/constants/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/cell.dart';

class CellTile extends StatelessWidget {
  final Cell cell;
  final bool isConflict;
  final bool isHint;
  final bool isSelected;
  final VoidCallback onTap;

  const CellTile({
    super.key,
    required this.cell,
    required this.onTap,
    this.isConflict = false,
    this.isHint = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    if (cell.isIceBlock) return const IceBlockTile();

    Color bg = Colors.transparent;
    if (isConflict) bg = AppColors.conflict.withOpacity(0.2);
    if (isHint) bg = AppColors.hint.withOpacity(0.3);
    if (isSelected) bg = AppColors.primary.withOpacity(0.15);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: cell.hasNumber
            ? Text(
                SymbolSystem.fromValue(cell.value!),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cell.isFixed ? AppColors.fixedNumber : AppColors.playerNumber,
                ),
              )
            : null,
      ),
    );
  }
}

class IceBlockTile extends StatelessWidget {
  const IceBlockTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: AppColors.iceBlock,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.iceBlockBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.iceBlock.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Write number_panel.dart**

```dart
// lib/presentation/widgets/number_panel.dart
import 'package:flutter/material.dart';
import '../../core/constants/symbols.dart';
import '../../core/theme/app_colors.dart';

class NumberPanel extends StatelessWidget {
  final int boardSize;
  final String? selectedSymbol;
  final void Function(String) onSymbolSelected;

  const NumberPanel({
    super.key,
    required this.boardSize,
    required this.selectedSymbol,
    required this.onSymbolSelected,
  });

  @override
  Widget build(BuildContext context) {
    final symbols = SymbolSystem.forSize(boardSize);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: symbols.map((sym) {
        final isSelected = sym == selectedSymbol;
        return GestureDetector(
          onTap: () => onSymbolSelected(sym),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              sym,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 3: Write game_controls.dart**

```dart
// lib/presentation/widgets/game_controls.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class GameControls extends StatelessWidget {
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final VoidCallback onClear;
  final bool canUndo;

  const GameControls({
    super.key,
    required this.onUndo,
    required this.onHint,
    required this.onClear,
    this.canUndo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon: Icons.undo,
          label: 'Undo',
          onTap: canUndo ? onUndo : null,
        ),
        _ControlButton(icon: Icons.lightbulb_outline, label: 'Hint', onTap: onHint),
        _ControlButton(icon: Icons.backspace_outlined, label: 'Clear', onTap: onClear),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/
git commit -m "feat: add CellTile, IceBlockTile, NumberPanel, GameControls widgets"
```

---

## Task 17: SudokuGrid Widget

**Files:**
- Create: `lib/presentation/widgets/sudoku_grid.dart`

- [ ] **Step 1: Write sudoku_grid.dart**

```dart
// lib/presentation/widgets/sudoku_grid.dart
import 'package:flutter/material.dart';
import '../../core/constants/board_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/position.dart';
import '../../domain/models/board.dart';
import 'cell_tile.dart';

class SudokuGrid extends StatelessWidget {
  final Board board;
  final List<(int, int)> conflicts;
  final Position? hintCell;
  final Position? selectedCell;
  final void Function(int row, int col) onCellTap;

  const SudokuGrid({
    super.key,
    required this.board,
    required this.onCellTap,
    this.conflicts = const [],
    this.hintCell,
    this.selectedCell,
  });

  @override
  Widget build(BuildContext context) {
    final boardSize = BoardSize.fromInt(board.size);
    final conflictSet = conflicts.map((e) => '${e.$1},${e.$2}').toSet();
    final grid = InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _GridPainter(boardSize),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: board.size,
            ),
            itemCount: board.size * board.size,
            itemBuilder: (ctx, idx) {
              final row = idx ~/ board.size;
              final col = idx % board.size;
              final cell = board.cellAt(row, col);
              final key = '$row,$col';
              return CellTile(
                cell: cell,
                isConflict: conflictSet.contains(key),
                isHint: hintCell?.row == row && hintCell?.col == col,
                isSelected: selectedCell?.row == row && selectedCell?.col == col,
                onTap: () => onCellTap(row, col),
              );
            },
          ),
        ),
      ),
    );

    return board.size > 12 ? grid : AspectRatio(aspectRatio: 1, child: grid);
  }
}

class _GridPainter extends CustomPainter {
  final BoardSize boardSize;
  _GridPainter(this.boardSize);

  @override
  void paint(Canvas canvas, Size size) {
    final n = boardSize.n;
    final cellSize = size.width / n;
    final thin = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 0.5;
    final bold = Paint()
      ..color = AppColors.gridLineBold
      ..strokeWidth = 2.0;

    for (var i = 0; i <= n; i++) {
      final isBold = i % boardSize.subRows == 0;
      final p = thin..color = isBold ? AppColors.gridLineBold : AppColors.gridLine;
      p.strokeWidth = isBold ? 2.0 : 0.5;
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, size.height),
        p,
      );
      final isBoldH = i % boardSize.subCols == 0;
      final ph = Paint()
        ..color = isBoldH ? AppColors.gridLineBold : AppColors.gridLine
        ..strokeWidth = isBoldH ? 2.0 : 0.5;
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(size.width, i * cellSize),
        ph,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.boardSize != boardSize;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/sudoku_grid.dart
git commit -m "feat: add SudokuGrid widget with CustomPainter grid lines"
```

---

## Task 18: Falling Number Overlay

**Files:**
- Create: `lib/presentation/widgets/falling_number_overlay.dart`

- [ ] **Step 1: Write falling_number_overlay.dart**

```dart
// lib/presentation/widgets/falling_number_overlay.dart
import 'package:flutter/material.dart';
import '../../core/constants/symbols.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/gravity_result.dart';

class FallingNumberOverlay extends StatefulWidget {
  final GravityResult result;
  final int value;
  final double cellSize;
  final VoidCallback onComplete;

  const FallingNumberOverlay({
    super.key,
    required this.result,
    required this.value,
    required this.cellSize,
    required this.onComplete,
  });

  @override
  State<FallingNumberOverlay> createState() => _FallingNumberOverlayState();
}

class _FallingNumberOverlayState extends State<FallingNumberOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final distance = (widget.result.toRow - widget.result.fromRow).abs();
    final duration = Duration(milliseconds: 150 + distance * 50);

    _ctrl = AnimationController(vsync: this, duration: duration);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _ctrl.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fromY = widget.result.fromRow * widget.cellSize;
    final toY = widget.result.toRow * widget.cellSize;
    final x = widget.result.col * widget.cellSize;

    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        final y = fromY + (toY - fromY) * _anim.value;
        return Positioned(
          left: x,
          top: y,
          width: widget.cellSize,
          height: widget.cellSize,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.9),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              SymbolSystem.fromValue(widget.value),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/widgets/falling_number_overlay.dart
git commit -m "feat: add FallingNumberOverlay animation widget"
```

---

## Task 19: Game Screen

**Files:**
- Create: `lib/presentation/screens/game/game_screen.dart`

- [ ] **Step 1: Write game_screen.dart**

```dart
// lib/presentation/screens/game/game_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/services/gravity_engine.dart';
import '../../../domain/services/hint_service.dart';
import '../../../domain/services/sudoku_validator.dart';
import '../../bloc/game/game_bloc.dart';
import '../../bloc/game/game_event.dart';
import '../../bloc/game/game_state.dart';
import '../../widgets/game_controls.dart';
import '../../widgets/number_panel.dart';
import '../../widgets/sudoku_grid.dart';

class GameScreen extends StatelessWidget {
  final Puzzle puzzle;

  const GameScreen({super.key, required this.puzzle});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameBloc(
        initialBoard: puzzle.initialBoard,
        gravity: GravityEngine(),
        validator: SudokuValidator(),
        hint: HintService(gravity: GravityEngine(), validator: SudokuValidator()),
        boardSize: puzzle.size,
      ),
      child: _GameView(puzzle: puzzle),
    );
  }
}

class _GameView extends StatelessWidget {
  final Puzzle puzzle;
  const _GameView({required this.puzzle});

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameBloc, GameState>(
      listenWhen: (prev, curr) => curr.status == GameStatus.completed && prev.status != GameStatus.completed,
      listener: (context, state) {
        Navigator.of(context).pushReplacementNamed(
          '/completion',
          arguments: {'stars': state.stars, 'time': state.elapsedSeconds},
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Level ${puzzle.id}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: () => _showPauseMenu(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _TimerRow(),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: BlocBuilder<GameBloc, GameState>(
                  buildWhen: (p, c) =>
                      p.board != c.board ||
                      p.conflicts != c.conflicts ||
                      p.hintCell != c.hintCell,
                  builder: (context, state) => SudokuGrid(
                    board: state.board,
                    conflicts: state.conflicts,
                    hintCell: state.hintCell,
                    onCellTap: (row, col) {
                      context.read<GameBloc>().add(PlaceNumber(row, col));
                    },
                  ),
                ),
              ),
              const Spacer(),
              BlocBuilder<GameBloc, GameState>(
                buildWhen: (p, c) => p.undoStack.length != c.undoStack.length,
                builder: (context, state) => GameControls(
                  canUndo: state.undoStack.isNotEmpty,
                  onUndo: () => context.read<GameBloc>().add(const UndoMove()),
                  onHint: () => context.read<GameBloc>().add(const RequestHint()),
                  onClear: () {}, // handled per-cell in future
                ),
              ),
              const SizedBox(height: 12),
              BlocBuilder<GameBloc, GameState>(
                buildWhen: (p, c) => p.selectedSymbol != c.selectedSymbol,
                builder: (context, state) => NumberPanel(
                  boardSize: puzzle.size,
                  selectedSymbol: state.selectedSymbol,
                  onSymbolSelected: (sym) =>
                      context.read<GameBloc>().add(SelectSymbol(sym)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showPauseMenu(BuildContext context) {
    context.read<GameBloc>().add(const PauseGame());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Paused'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<GameBloc>().add(const ResumeGame());
            },
            child: const Text('Resume'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<GameBloc>().add(const RestartPuzzle());
            },
            child: const Text('Restart'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pop();
            },
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }
}

class _TimerRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (p, c) => p.elapsedSeconds != c.elapsedSeconds,
      builder: (context, state) {
        final m = state.elapsedSeconds ~/ 60;
        final s = state.elapsedSeconds % 60;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}  •  ${state.moveCount} moves',
            style: const TextStyle(fontSize: 14),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/screens/game/
git commit -m "feat: add GameScreen"
```

---

## Task 20: Remaining Screens

**Files:**
- Create: `lib/presentation/screens/home/home_screen.dart`
- Create: `lib/presentation/screens/level_select/level_select_screen.dart`
- Create: `lib/presentation/screens/completion/completion_screen.dart`

- [ ] **Step 1: Write home_screen.dart**

```dart
// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Gravity Sudoku',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sudoku meets gravity',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed('/levels'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Text('Play', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/levels', arguments: 'daily'),
                child: const Text('Daily Challenge'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
                child: const Text('Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Write level_select_screen.dart**

```dart
// lib/presentation/screens/level_select/level_select_screen.dart
import 'package:flutter/material.dart';
import '../../../domain/models/puzzle.dart';
import '../game/game_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  final List<Puzzle> puzzles;
  final Difficulty difficulty;

  const LevelSelectScreen({
    super.key,
    required this.puzzles,
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(difficulty.name.toUpperCase())),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: puzzles.length,
        itemBuilder: (ctx, i) {
          final puzzle = puzzles[i];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GameScreen(puzzle: puzzle)),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '${i + 1}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: Write completion_screen.dart**

```dart
// lib/presentation/screens/completion/completion_screen.dart
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CompletionScreen extends StatefulWidget {
  final int stars;
  final int elapsedSeconds;

  const CompletionScreen({
    super.key,
    required this.stars,
    required this.elapsedSeconds,
  });

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.elapsedSeconds ~/ 60;
    final s = widget.elapsedSeconds % 60;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Puzzle Complete!',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Icon(
                    i < widget.stars ? Icons.star : Icons.star_border,
                    color: AppColors.hint,
                    size: 40,
                  )),
                ),
                const SizedBox(height: 16),
                Text('Time: ${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}'),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/
git commit -m "feat: add Home, LevelSelect, Completion screens"
```

---

## Task 21: Main App Entry Point

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Write main.dart**

```dart
// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'data/local/database/app_database.dart';
import 'data/local/prefs/preferences_service.dart';
import 'data/repositories/local_puzzle_repository.dart';
import 'data/repositories/local_progress_repository.dart';
import 'domain/models/puzzle.dart';
import 'presentation/screens/completion/completion_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/level_select/level_select_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final db = AppDatabase();
  final prefs = PreferencesService(await SharedPreferences.getInstance());
  final puzzleRepo = LocalPuzzleRepository(db);
  final progressRepo = LocalProgressRepository(db);

  // Seed puzzles from assets on first run
  await _seedPuzzles(puzzleRepo);

  runApp(GravitySudokuApp(
    prefs: prefs,
    puzzleRepo: puzzleRepo,
    progressRepo: progressRepo,
  ));
}

Future<void> _seedPuzzles(LocalPuzzleRepository repo) async {
  final files = [
    'assets/puzzles/easy_4x4.json',
    'assets/puzzles/normal_9x9.json',
    'assets/puzzles/hard_12x12.json',
    'assets/puzzles/expert_16x16.json',
    'assets/puzzles/extreme_32x32.json',
  ];

  for (final path in files) {
    try {
      final raw = await rootBundle.loadString(path);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final puzzles = data['puzzles'] as List;
      for (final p in puzzles) {
        await repo.insertFromJson(p as Map<String, dynamic>);
      }
    } catch (_) {}
  }
}

class GravitySudokuApp extends StatelessWidget {
  final PreferencesService prefs;
  final LocalPuzzleRepository puzzleRepo;
  final LocalProgressRepository progressRepo;

  const GravitySudokuApp({
    super.key,
    required this.prefs,
    required this.puzzleRepo,
    required this.progressRepo,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = prefs.selectedTheme == 'dark';
    return MaterialApp(
      title: 'Gravity Sudoku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/levels':
            return MaterialPageRoute(
              builder: (_) => FutureBuilder(
                future: puzzleRepo.fetchByDifficulty(Difficulty.easy),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  return LevelSelectScreen(
                    puzzles: snap.data!,
                    difficulty: Difficulty.easy,
                  );
                },
              ),
            );
          case '/completion':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => CompletionScreen(
                stars: args['stars'] as int,
                elapsedSeconds: args['time'] as int,
              ),
            );
          default:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire up main app entry point with routing"
```

---

## Task 22: Run & Verify

- [ ] **Step 1: Run all tests**

```bash
flutter test
```

Expected: All tests PASS.

- [ ] **Step 2: Run web preview**

```bash
flutter run -d chrome
```

Expected: Browser opens, app loads on HomeScreen. Click Play → LevelSelect → tap a level → GameScreen with grid appears.

- [ ] **Step 3: Verify core flow**

1. Open app in browser
2. Tap "Play" → level list appears
3. Tap level 1 → 4×4 grid appears with pre-filled numbers
4. Tap a number on the Number Panel (e.g., "2")
5. Tap an empty column in the grid → number animates falling to the bottom
6. Tap Undo → number returns
7. Verify timer is counting up

- [ ] **Step 4: Run on Android (if device connected)**

```bash
flutter run -d android
```

Expected: App installs and runs on device.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: final integration and verification"
```

---

## Post-Implementation Notes

- **Puzzle content:** Only 2 puzzles exist in the JSON files. A puzzle author or generator should populate the remaining 358+ puzzles before release.
- **Audio files:** Placeholder paths in `assets/audio/` — real `.mp3` files must be added before audio works.
- **Ads integration:** `google_mobile_ads` is in pubspec but not wired up — wire at `HomeScreen` and `CompletionScreen` before release.
- **32×32 board:** Symbols render at small size — the `InteractiveViewer` in `SudokuGrid` allows pinch-to-zoom to compensate.
- **Difficulty tabs on LevelSelectScreen:** Currently shows only Easy puzzles — extend `onGenerateRoute` to pass difficulty argument.
