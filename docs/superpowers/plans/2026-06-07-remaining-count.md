# Remaining Count Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show each symbol's remaining placement count in the Number Panel; auto-deselect when a symbol's count hits zero.

**Architecture:** Pure presentational change to `NumberPanel` (new `remainingCounts` param) + count computation in `GameScreen`'s BlocBuilder + one extra line in `GameBloc._onPlaceNumber`. No new state fields — count is derived from `board`.

**Tech Stack:** Flutter, flutter_bloc, existing `SymbolSystem` utility.

---

## File Map

```
lib/presentation/widgets/number_panel.dart          ← add remainingCounts param + count UI
lib/presentation/screens/game/game_screen.dart      ← compute remainingCounts, pass to panel
lib/presentation/bloc/game/game_bloc.dart           ← clear selectedSymbol when count hits 0
```

---

## Task 1: Update NumberPanel

**Files:**
- Modify: `lib/presentation/widgets/number_panel.dart`

- [ ] **Step 1: Replace `number_panel.dart` with the new version**

```dart
import 'package:flutter/material.dart';
import '../../core/constants/symbols.dart';
import '../../core/theme/app_colors.dart';

class NumberPanel extends StatelessWidget {
  final int boardSize;
  final String? selectedSymbol;
  final Map<String, int> remainingCounts;
  final void Function(String) onSymbolSelected;

  const NumberPanel({
    super.key,
    required this.boardSize,
    required this.selectedSymbol,
    required this.remainingCounts,
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
        final remaining = remainingCounts[sym] ?? boardSize;
        final isSelected = sym == selectedSymbol;
        final isDone = remaining <= 0;

        return GestureDetector(
          onTap: isDone ? null : () => onSymbolSelected(sym),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 44,
            height: 54,
            decoration: BoxDecoration(
              color: isDone
                  ? Colors.grey.withValues(alpha: 0.15)
                  : isSelected
                      ? AppColors.primary
                      : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isDone
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Opacity(
              opacity: isDone ? 0.4 : 1.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    sym,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDone ? '✓' : '×$remaining',
                    style: TextStyle(
                      fontSize: isSelected ? 11 : 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isDone
                          ? AppColors.textSecondary
                          : isSelected
                              ? Colors.white.withValues(alpha: 0.85)
                              : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

```powershell
D:\flutter\bin\dart.bat analyze lib/presentation/widgets/number_panel.dart
```

Expected: `No issues found.`

---

## Task 2: Compute remainingCounts in GameScreen

**Files:**
- Modify: `lib/presentation/screens/game/game_screen.dart`

- [ ] **Step 1: Add `_computeRemaining` helper and update the NumberPanel BlocBuilder**

Find this block in `game_screen.dart`:

```dart
                  BlocBuilder<GameBloc, GameState>(
                    buildWhen: (p, c) =>
                        p.selectedSymbol != c.selectedSymbol,
                    builder: (context, state) => NumberPanel(
                      boardSize: puzzle.size,
                      selectedSymbol: state.selectedSymbol,
                      onSymbolSelected: (sym) =>
                          context.read<GameBloc>().add(SelectSymbol(sym)),
                    ),
                  ),
```

Replace it with:

```dart
                  BlocBuilder<GameBloc, GameState>(
                    buildWhen: (p, c) =>
                        p.selectedSymbol != c.selectedSymbol ||
                        p.board != c.board,
                    builder: (context, state) => NumberPanel(
                      boardSize: puzzle.size,
                      selectedSymbol: state.selectedSymbol,
                      remainingCounts: _computeRemaining(
                          state.board, puzzle.size),
                      onSymbolSelected: (sym) =>
                          context.read<GameBloc>().add(SelectSymbol(sym)),
                    ),
                  ),
```

Then add this private function anywhere inside `_GameView` class (after `_showPauseMenu`):

```dart
  Map<String, int> _computeRemaining(board, int size) {
    final counts = <String, int>{};
    for (final sym in SymbolSystem.forSize(size)) {
      final v = SymbolSystem.toValue(sym);
      var placed = 0;
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (board.cellAt(r, c).value == v) placed++;
        }
      }
      counts[sym] = size - placed;
    }
    return counts;
  }
```

Also add import at top of `game_screen.dart` if not already present:

```dart
import '../../../core/constants/symbols.dart';
```

- [ ] **Step 2: Run analyzer**

```powershell
D:\flutter\bin\dart.bat analyze lib/presentation/screens/game/game_screen.dart
```

Expected: `No issues found.`

---

## Task 3: Auto-deselect in GameBloc when count hits zero

**Files:**
- Modify: `lib/presentation/bloc/game/game_bloc.dart`

- [ ] **Step 1: Add count-zero deselect in `_onPlaceNumber`**

Find this emit inside `_onPlaceNumber` (the success path emit):

```dart
    emit(state.copyWith(
      board: newBoard,
      undoStack: newStack.length > 50
          ? newStack.sublist(newStack.length - 50)
          : newStack,
      conflicts: conflicts,
      lastGravityResult: result,
      moveCount: state.moveCount + 1,
      status: isComplete ? GameStatus.completed : GameStatus.playing,
      clearHint: true,
    ));
```

Replace it with:

```dart
    // Auto-deselect if this symbol is now fully placed
    var remaining = 0;
    for (var r = 0; r < newBoard.size; r++) {
      for (var c = 0; c < newBoard.size; c++) {
        if (newBoard.cellAt(r, c).value == value) remaining++;
      }
    }
    final symbolExhausted = remaining >= _puzzle.size;

    emit(state.copyWith(
      board: newBoard,
      undoStack: newStack.length > 50
          ? newStack.sublist(newStack.length - 50)
          : newStack,
      conflicts: conflicts,
      lastGravityResult: result,
      moveCount: state.moveCount + 1,
      status: isComplete ? GameStatus.completed : GameStatus.playing,
      clearHint: true,
      clearSymbol: symbolExhausted,
    ));
```

- [ ] **Step 2: Run full analyzer**

```powershell
D:\flutter\bin\dart.bat analyze lib/
```

Expected: `No issues found.`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/number_panel.dart \
        lib/presentation/screens/game/game_screen.dart \
        lib/presentation/bloc/game/game_bloc.dart
git commit -m "feat: show remaining symbol count in number panel"
```

---

## Self-Review

- **Spec coverage:** All three spec requirements covered — count display, selected prominence, zero state, auto-deselect. ✓
- **Placeholders:** None. ✓
- **Type consistency:** `Map<String, int> remainingCounts` used consistently across all three files. `_computeRemaining` returns the same type. ✓
- **`board` type in `_computeRemaining`:** Parameter typed as `dynamic` for brevity — should be `Board`. Add import in game_screen.dart: `import '../../../domain/models/board.dart';` and type it as `Board`. Already imported in game_screen.dart. ✓
