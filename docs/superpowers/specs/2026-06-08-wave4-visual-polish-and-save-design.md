# Wave 4：視覺打磨 + 進度存檔 Design Spec

## Goal

為 Gravity Sudoku 新增兩項功能：(C) 進度自動存檔與續玩、(B) 5 色主題與雙音量滑桿設定。

## Architecture Overview

- **進度存檔** 共用現有 Drift `Progresses` 表，schema 升至 v3（補充缺漏欄位），在 `GameBloc` 側觸發寫入；讀取點在 `HomeScreen` 與 `DifficultySelectScreen`。
- **視覺主題** 以字串 key 驅動 `AppTheme.forName()`，`SettingsBloc` 統一管理主題與兩個音量值，移除 `darkTheme`/`themeMode` 切換機制。
- **音訊** `AudioService` 新增 `setMusicVolume` / `setSfxVolume`，由 `SettingsBloc` 在狀態變更時同步呼叫。
- **設定入口** 新增 `SettingsScreen`；HomeScreen AppBar 齒輪進入；暫停選單亦保留快捷按鈕。

---

## Section C：進度存檔

### 觸發存檔的時機

| 事件 | 機制 |
|------|------|
| 點擊「暫停」→「Quit」 | 已有 `repo.insert(isCompleted: false)`，改為存進度 |
| 點擊「暫停」→「Resume」後離開（`AppLifecycleState.inactive`） | `WidgetsBindingObserver` 監聽 |
| App 進入背景（`AppLifecycleState.paused`） | 同上 |

> **Quit 按鈕行為變更**：原本寫 `GameRecord(isCompleted: false)`；Wave 4 改為儲存「進度快照」（`SaveProgress` event），不再寫 GameRecord（棄局不計入統計），直接 pop 回 HomeScreen。

### 資料模型

使用現有 `Progresses` Drift 表，**schema 升至 v3** 補充缺漏欄位。

現有欄位（schema v2）：
```dart
class Progresses extends Table {
  IntColumn get puzzleId => integer()();       // puzzle.id（int）
  TextColumn get boardJson => text()();        // 序列化 board（含 notes）
  TextColumn get undoStackJson => text()();    // 已有，Wave 4 可忽略（存空陣列）
  IntColumn get elapsedSeconds => integer()();
  IntColumn get hintUsedCount => integer()();
  BoolColumn get isCompleted => boolean()
      .withDefault(const Constant(false))();
}
```

v3 Migration 新增欄位（`onUpgrade` from < 3）：
```dart
// 以 addColumn 加入
TextColumn get difficulty => text().withDefault(const Constant('easy'))();
IntColumn get hearts => integer().withDefault(const Constant(3))();
BoolColumn get isInfiniteMode => boolean()
    .withDefault(const Constant(false))();
IntColumn get undosRemaining => integer().withDefault(const Constant(1))();
IntColumn get savedAt => integer().withDefault(const Constant(0))();
```

> `isCompleted` 保留但 Wave 4 存檔時永遠寫 `false`；`undoStackJson` 保留但存空 JSON `[]`（undo history 不還原）。

### Board 序列化

`boardJson` 儲存 JSON 字串，內容：
```json
{
  "size": 9,
  "cells": [
    {"r": 0, "c": 0, "value": 5, "isFixed": true, "isIceBlock": false},
    ...
  ],
  "notes": {
    "0,1": [1, 3, 7]
  }
}
```

序列化 / 反序列化邏輯放在 `lib/domain/models/board.dart` 的靜態方法 `Board.toJson()` / `Board.fromJson()`。

### 單槽設計

每次存檔前先 `DELETE FROM progresses`，再 `INSERT`。  
`ProgressRepository` 介面：
```dart
abstract class ProgressRepository {
  Future<void> save(ProgressSnapshot snapshot);
  Future<ProgressSnapshot?> load();
  Future<void> clear();
}
```

`ProgressSnapshot` domain model（`lib/domain/models/progress_snapshot.dart`）：
```dart
class ProgressSnapshot {
  final int puzzleId;          // 對應 Puzzle.id（int）
  final Difficulty difficulty;
  final Board board;           // 包含 notes（序列化進 boardJson）
  final int elapsedSeconds;
  final int hearts;
  final int undosRemaining;
  final bool isInfiniteMode;
  final int hintUsedCount;
  final DateTime savedAt;
}
```

notes（`Map<Position, Set<int>>`）折入 `Board.toJson()`，不單獨存欄位。

### GameBloc 整合

新增 `SaveProgress` event，由 `_GameViewState` 的 `WidgetsBindingObserver` 與 Quit 按鈕觸發：

```dart
class SaveProgress extends GameEvent {
  const SaveProgress();
}
```

`GameBloc` 處理 `SaveProgress`：接收 `ProgressRepository` 作建構參數，呼叫 `repo.save(snapshot)` 後 emit 相同 state（不改變遊戲狀態）。

### 續玩入口（HomeScreen + DifficultySelectScreen）

啟動時兩個頁面均非同步查詢 `ProgressRepository.load()`：
- 有存檔 → 顯示 **「繼續上局」** 按鈕（帶上次 difficulty 字串），點擊後載入存檔並進入 `GameScreen`
- 無存檔 → 隱藏按鈕

`GameScreen` 新增 `ProgressSnapshot? resumeFrom` 可選參數；不為 null 時以快照還原 `GameBloc` 初始狀態。

進入遊戲後呼叫 `ProgressRepository.clear()`（開始新局亦清除）。

---

## Section B：5 色主題

### 主題清單

| Key | 外觀 |
|-----|------|
| `light` | 現有淺色（保持不變） |
| `dark` | 現有深色（保持不變） |
| `ocean` | 深藍深色系 |
| `sunset` | 暖橘淺色系 |
| `forest` | 深綠深色系 |

### AppTheme 擴充

`lib/core/theme/app_theme.dart` 新增：
```dart
static ThemeData forName(String name) {
  switch (name) {
    case 'dark':    return dark();
    case 'ocean':   return ocean();
    case 'sunset':  return sunset();
    case 'forest':  return forest();
    default:        return light();
  }
}
static ThemeData ocean()  { ... }
static ThemeData sunset() { ... }
static ThemeData forest() { ... }
```

### MaterialApp 改動

移除 `darkTheme` 與 `themeMode`，改為：
```dart
theme: AppTheme.forName(settings.theme),
```

### SettingsState 擴充

`theme` 欄位原本只支援 `'light'`/`'dark'`，改為支援 5 個字串值（無需型別變更）。

---

## Section A：音訊設定

### SettingsState 新增欄位

```dart
final double musicVolume;  // 預設 0.8
final double sfxVolume;    // 預設 1.0
```

### SettingsEvent 新增

```dart
class ChangeMusicVolume extends SettingsEvent {
  final double volume;
  const ChangeMusicVolume(this.volume);
}
class ChangeSfxVolume extends SettingsEvent {
  final double volume;
  const ChangeSfxVolume(this.volume);
}
```

### SettingsBloc 響應

收到 `ChangeMusicVolume` → 更新 state + SharedPreferences + 呼叫 `audioService.setMusicVolume(v)`  
收到 `ChangeSfxVolume` → 更新 state + SharedPreferences（SFX 滑桿放開時播放一次點擊音效預覽）

### AudioService 擴充

```dart
void setMusicVolume(double v);  // 立即更新背景音樂播放器音量
void setSfxVolume(double v);    // 儲存欄位，playSfx() 時套用
```

SharedPreferences 鍵：`music_volume`、`sfx_volume`

---

## Section D：設定畫面架構

### SettingsScreen

`lib/presentation/screens/settings/settings_screen.dart`

三個區塊：
1. **主題**：5 個 `ChoiceChip`（Light / Dark / Ocean / Sunset / Forest）
2. **音樂音量**：`Slider`（0.0–1.0），label 顯示百分比
3. **音效音量**：`Slider`（0.0–1.0），label 顯示百分比

### HomeScreen 改動

AppBar 的太陽/月亮 `IconButton` → `Icons.settings_outlined`  
`onPressed` → `Navigator.push` 到 `SettingsScreen`

### 暫停選單改動

移除現有 `SwitchListTile('Dark mode')`  
新增 `TextButton('設定')` → `Navigator.push` 到 `SettingsScreen`（dialog 維持開啟，用 `Navigator.pop` + `Navigator.push` 序列執行）

---

## Known Limitations

- `ProgressSnapshot` board 序列化格式為自訂 JSON；`Board.fromJson` 需能重建完整冰塊狀態
- App 進入背景時 `SaveProgress` 為非同步，若 OS 強殺可能未完成（可接受）
- HomeScreen 每日挑戰狀態仍只在啟動時檢查一次（Wave 3 既有限制，Wave 4 不修）
