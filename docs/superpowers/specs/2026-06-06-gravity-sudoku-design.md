# Gravity Sudoku — Game Design Spec

**Date:** 2026-06-06  
**Platform:** Flutter (Android + Web preview)  
**Project path:** `D:\projects\gravity-sudoku`

---

## 1. Concept

Gravity Sudoku combines standard Sudoku logic with real-time downward gravity. When a player places a number, it immediately falls to the lowest available position in its column — the bottom of the board, the top of another number, or directly above an ice block. Players must predict the final landing position before placing each number.

---

## 2. Architecture — Clean Architecture (Option B)

```
lib/
├── core/
│   ├── theme/          # Light / dark themes, fonts, colors
│   ├── constants/      # Board sizes, symbol tables
│   └── utils/          # Shared helpers
│
├── domain/             # Pure Dart — zero Flutter dependency
│   ├── models/
│   │   ├── cell.dart           # value, isFixed, isIceBlock
│   │   ├── board.dart          # 2D Cell grid + mutation methods
│   │   ├── puzzle.dart         # Board + solution + metadata
│   │   └── gravity_result.dart # fromRow, toRow, col
│   ├── services/
│   │   ├── sudoku_validator.dart   # Row / col / subgrid uniqueness
│   │   ├── gravity_engine.dart     # Column fall simulation
│   │   └── hint_service.dart       # Best safe move finder
│   └── repositories/           # Abstract interfaces
│       ├── puzzle_repository.dart
│       └── progress_repository.dart
│
├── data/
│   ├── local/
│   │   ├── database/   # drift (SQLite) — puzzles & progress
│   │   └── prefs/      # SharedPreferences — settings, theme
│   └── repositories/   # Concrete implementations
│
└── presentation/
    ├── bloc/
    │   ├── game/        # GameBloc
    │   └── settings/    # SettingsBloc
    ├── screens/
    │   ├── home/
    │   ├── level_select/
    │   ├── game/
    │   └── completion/
    └── widgets/
        ├── sudoku_grid.dart
        ├── cell_tile.dart
        ├── ice_block_tile.dart
        ├── number_panel.dart
        └── game_controls.dart
```

**Layer rules:**
- `domain/` has no Flutter imports. All logic is unit-testable with pure Dart.
- `presentation/` communicates with domain only through Bloc events/states.
- `data/` implementations are injected into Blocs via repository interfaces.

---

## 3. Board Sizes & Symbol System

| Size  | Subgrid | Symbols         | Notes                        |
|-------|---------|-----------------|------------------------------|
| 4×4   | 2×2     | 1–4             | Entry level                  |
| 9×9   | 3×3     | 1–9             | Standard Sudoku              |
| 12×12 | 3×4     | 1–9, A–C        | Letter extension             |
| 16×16 | 4×4     | 1–9, A–G        | Hex style                    |
| 32×32 | 4×8     | 1–9, A–W        | Pinch-to-zoom required       |

For 32×32, the grid supports pinch-to-zoom and two-finger pan. Symbols use a tap-to-confirm tooltip to prevent misplacement on small tiles.

---

## 4. Core Game Mechanics

### 4.1 Gravity Engine

After a number is placed in a column, the engine simulates a downward fall:

```
Start at selected row (any row in the column triggers the same result)
Scan downward cell by cell:
  Stop if next cell is bottom boundary
  Stop if next cell contains a number
  Stop if next cell is an ice block
Final position = last valid empty cell
```

Returns `GravityResult { fromRow, toRow, col }` consumed by the animation layer.

**Input flow:** Player taps a symbol on the Number Panel (highlights it), then taps any cell in the target column. The row tapped is ignored — only the column is used. The number is placed at the gravity-resolved landing position.

**Key design decision:** The player's chosen row within a column is irrelevant — only the column matters. The number always lands at the same position regardless of where in the column the player taps. This simplifies input while keeping strategy in column selection and number ordering.

### 4.2 Sudoku Validator

Runs after gravity resolves. Validates the board in its post-fall state:
- No duplicate in any row
- No duplicate in any column
- No duplicate in any subgrid

Conflicting cells are flagged for error animation.

### 4.3 Undo Stack

Stores full Board snapshots (not diffs). Maximum 50 steps. Undo replays the reverse gravity animation (number floats back upward). Using undo does not reduce star rating.

### 4.4 Hint Service

Scans all empty columns, finds the move with the most deterministic landing position and no rule violations, highlights the target column and suggested symbol. Each hint use reduces star rating by 1.

---

## 5. State Management — GameBloc

### Events
```
PlaceNumber(col, symbol)
SelectSymbol(symbol)
UndoMove()
RestartPuzzle()
RequestHint()
PauseGame()
ResumeGame()
```

### State
```
board          Board
selectedSymbol String?
undoStack      List<Board>     # max 50
hintCell       Position?
status         GameStatus      # playing | paused | completed
moveCount      int
elapsedSeconds int
hintUsedCount  int
```

### PlaceNumber flow
```
1. GravityEngine.simulate(board, col) → GravityResult
2. board.apply(result) → newBoard
3. SudokuValidator.validate(newBoard) → conflicts
4. undoStack.push(currentBoard)
5. emit new state → UI triggers fall animation
6. if board.isComplete → emit completed
```

---

## 6. Data Layer

### SQLite (drift) Tables

**puzzles**
```
id            INTEGER PRIMARY KEY
size          INTEGER   (4, 9, 12, 16, 32)
difficulty    TEXT      (easy | normal | hard | expert | extreme)
board_json    TEXT      (initial cells + ice block positions)
solution_json TEXT
ice_blocks_json TEXT
```

**progress**
```
puzzle_id       INTEGER REFERENCES puzzles(id)
board_json      TEXT    (current state)
undo_stack_json TEXT
elapsed_seconds INTEGER
hint_used_count INTEGER
is_completed    BOOLEAN
```

### SharedPreferences Keys
```
selected_theme         String
sfx_enabled            bool
music_enabled          bool
last_played_puzzle_id  int
```

### Offline Support

All puzzles are bundled in `assets/puzzles/` as JSON files, imported into SQLite on first launch. No network required for gameplay. Ads and achievements require connectivity.

---

## 7. Level & Progression System

| Difficulty | Sizes       | Ice Blocks | Levels |
|------------|-------------|------------|--------|
| Easy       | 4×4         | 0–2        | 50     |
| Normal     | 9×9         | 2–6        | 100    |
| Hard       | 9×9, 12×12  | 6–12       | 100    |
| Expert     | 16×16       | 10–20      | 80     |
| Extreme    | 32×32       | Any        | 30     |
| Daily      | Rotating    | Random     | 1/day  |

**Total: 360+ handcrafted puzzles**

**Unlock gates:** Next difficulty unlocks after completing 60% of the current one.

**Star rating:**
- 3 stars: no hints used
- 2 stars: 1 hint used
- 1 star: 2+ hints used

**Achievements (20 total, examples):**
- First Expert clear with no hints
- 7-day Daily Challenge streak
- Complete all Easy levels
- Use undo 0 times in a Hard level

---

## 8. UI Screens

### GameScreen Layout (Portrait)
```
┌─────────────────────────┐
│  [Back]   Lv.12  [Pause]│
│  ─────────────────────  │
│       Timer / Moves     │
├─────────────────────────┤
│                         │
│       Sudoku Grid       │  55–60% of screen height
│  (numbers + ice blocks) │
│                         │
├─────────────────────────┤
│  [Undo]  [Hint]  [Clear]│
├─────────────────────────┤
│                         │
│      Number Panel       │
│   1  2  3  4  5         │
│   6  7  8  9            │
│                         │
└─────────────────────────┘
```

### Other Screens
- **SplashScreen** — launch animation + data load
- **HomeScreen** — Play / Daily Challenge / Settings
- **LevelSelectScreen** — difficulty tabs + size filter, grid of level cards
- **CompletionScreen** — star animation + next level button
- **PauseMenuOverlay** — Resume / Restart / Quit

---

## 9. Animation System

| Animation         | Implementation                              | Duration         |
|-------------------|---------------------------------------------|------------------|
| Number fall        | `AnimatedPositioned` + `CurvedAnimation` (easeIn) | 200–400ms (by distance) |
| Landing bounce     | Scale 1.0 → 1.15 → 1.0, `ElasticOutCurve` | 180ms            |
| Landing particles  | `CustomPainter` radial dots, fade out       | 300ms            |
| Conflict flash     | Red background shake, `TweenSequence`      | 250ms            |
| Completion burst   | `confetti` package + board scale up        | 800ms            |
| Undo reverse       | Number floats up, opacity fade              | 200ms            |

---

## 10. Visual Design

- **Style:** Modern minimalist, geometric
- **Font:** Nunito (Google Fonts) — round, readable
- **Themes:** Light and Dark base; 3 paid cosmetic skins (color tint swap)
- **Ice blocks:** Frosted glass effect (`BackdropFilter` blur), light blue tint
- **Number tiles:** Rounded rectangles, soft drop shadow
- **Grid lines:** Thin for inner cells, bold for subgrid boundaries

---

## 11. Audio

| Sound           | Trigger                      |
|-----------------|------------------------------|
| Soft click      | Number panel selection       |
| Thud            | Number lands                 |
| Ice clink       | Number lands on ice block    |
| Error buzz      | Rule violation               |
| Completion chime| Puzzle solved                |
| Background music| Looping ambient track        |

All sounds toggle independently via SettingsBloc.

---

## 12. Monetization

| Item              | Type          | Price      |
|-------------------|---------------|------------|
| Rewarded ads      | Earn hints    | Free (5/day max) |
| Cosmetic skin ×3  | IAP           | $0.99 each |
| Remove ads        | IAP           | $2.99      |
| Daily Challenge   | Free feature  | —          |

---

## 13. Tech Stack

| Concern           | Package                    |
|-------------------|----------------------------|
| State management  | `flutter_bloc ^8`          |
| Local database    | `drift ^2` (SQLite)        |
| Preferences       | `shared_preferences`       |
| Fonts             | `google_fonts`             |
| Particles         | `confetti ^0.7`            |
| Ads               | `google_mobile_ads`        |
| Audio             | `audioplayers ^6`          |
| Web preview       | `flutter run -d chrome`    |

---

## 14. Technical Requirements

- Target: Android (Google Play Store ready)
- Web: development preview only (`flutter run -d chrome`)
- Min Android SDK: 21 (Android 5.0)
- Orientation: Portrait locked
- Auto-save: on every move via progress table
- Performance: 60 fps on mid-range devices; no heavy computation on main isolate for 32×32 puzzle generation
- Battery: no background processes, no polling
