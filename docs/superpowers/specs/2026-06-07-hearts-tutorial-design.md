# Hearts, Tutorial & Difficulty Expansion Design

## Goal

Add hearts (3 lives), a one-time undo limit, tutorial levels, and expanded puzzle content for all difficulty tiers.

## Architecture

Extend `GameState` with `hearts` and `undosRemaining`. Add `GameStatus.gameOver`. Add `Difficulty.tutorial`. Write new puzzle JSON assets. Add `DifficultySelectScreen` as the new entry point after Home.

## New Screens

- **DifficultySelectScreen** — replaces the direct `/levels` route from HomeScreen; lists Tutorial / Easy / Normal / Hard / Expert / Extreme
- **GameOverScreen** — shown when `hearts == 0`; offers Restart and Back to Home

## Hearts System

- `GameState.hearts` starts at 3; `GameState.undosRemaining` starts at 1
- When `PlaceNumber` is handled in `GameBloc._onPlaceNumber`:
  1. Simulate gravity to find `toRow`
  2. Compare `value` against `Puzzle.solution.cellAt(toRow, col).value`
  3. If mismatch → emit `hearts - 1`, do NOT place the number, emit `WrongAnswerFlash` event so UI shows red cell flash for 600ms
  4. If `hearts == 0` → emit `GameStatus.gameOver`; BlocListener navigates to `GameOverScreen`
- Tutorial puzzles (`puzzle.difficulty == Difficulty.tutorial`) skip hearts entirely; `hearts` stays at 3 and is not displayed

## Undo Limit

- `undosRemaining` starts at 1 for non-tutorial puzzles
- `_onUndo`: if `undosRemaining == 0`, return early (no-op); otherwise undo and set `undosRemaining = 0`
- `GameControls` undo button disabled when `undosRemaining == 0`
- Tutorial puzzles: `undosRemaining` starts at 99 (effectively unlimited)

## Wrong Answer Flash

New `GameStatus` value: no — instead, add a nullable `Position? wrongFlashCell` to `GameState`. Set it on wrong answer; cleared after 600ms via a `Timer` in `GameBloc`. `CellTile` shows red background when `wrongFlashCell == position`.

## Tutorial Levels

- `Difficulty.tutorial` added to enum
- 3 tutorial puzzles in `assets/puzzles/tutorial_4x4.json`
- Each puzzle has a `tutorialStep` string field (stored in JSON, passed through `Puzzle`)
- `GameScreen` shows a dismissible coach-mark overlay when `puzzle.tutorialStep != null`; overlay appears once on load, tap anywhere to dismiss
- Tutorial level does not show heart icons in the UI

## Puzzle Model Extension

`Puzzle` gains `final String? tutorialStep` — nullable, null for all non-tutorial puzzles.

## Difficulty Select Screen

Grid of 6 cards: Tutorial, Easy, Normal, Hard, Expert, Extreme. Each card shows the difficulty name and board size (e.g. "4×4", "9×9"). Tapping loads `LevelSelectScreen` with that difficulty's puzzles via `PuzzleRepository.fetchByDifficulty`.

## New Puzzle Content

| File | Puzzles | Size |
|------|---------|------|
| `tutorial_4x4.json` | 3 | 4×4 |
| `easy_4x4.json` | existing 2, keep | 4×4 |
| `normal_9x9.json` | 5 total | 9×9 |
| `hard_12x12.json` | 5 | 12×12 |
| `expert_16x16.json` | 3 | 16×16 |
| `extreme_32x32.json` | 2 | 32×32 |

All puzzle JSON must be valid Sudoku solutions (verified by hand or script).

## Stars Calculation Update

Stars now factor in both hints and hearts:
- 3 stars: no hints used, no hearts lost
- 2 stars: ≤1 hint OR lost 1 heart
- 1 star: otherwise

## Data Flow

```
HomeScreen → DifficultySelectScreen → LevelSelectScreen → GameScreen
                                                         ↓ hearts==0
                                                    GameOverScreen
                                                         ↓
                                                    DifficultySelectScreen
```
