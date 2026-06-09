# Remaining Count Display — Design Spec

**Date:** 2026-06-07
**Scope:** Number panel UI enhancement

---

## Feature

Each number button in the Number Panel shows how many times that symbol still needs to be placed. All buttons show a count at all times; the selected button's count is more prominent.

## Calculation

```
remaining[sym] = boardSize - placedCount(sym, board)
```

Computed in `GameScreen`'s `BlocBuilder` for `NumberPanel`, directly from `board` state. No changes to `GameState`.

## UI Behaviour

| State | Count display | Button style |
|-------|--------------|--------------|
| Normal (unselected) | Small grey `×N` below label | Unchanged |
| Selected | White `×N`, slightly larger | Highlighted (existing primary bg) |
| Count = 0 | `✓` symbol | 50% opacity, disabled (cannot select) |

## Files Changed

| File | Change |
|------|--------|
| `lib/presentation/widgets/number_panel.dart` | Add `remainingCounts: Map<String, int>` param; render count row; grey-out when 0 |
| `lib/presentation/screens/game/game_screen.dart` | Compute `remainingCounts` in `BlocBuilder`; pass to `NumberPanel`; rebuild on `board` change |
| `lib/presentation/bloc/game/game_bloc.dart` | In `_onPlaceNumber`: if remaining count hits 0 after placement, clear `selectedSymbol` |
