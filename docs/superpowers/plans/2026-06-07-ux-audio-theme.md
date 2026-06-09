# UX / Audio / Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 6 gameplay improvements: game-over/completion navigation, remove Level title, long-press number deselect, audio system, and dark/light theme toggle.

**Architecture:** AudioService wraps two audioplayers AudioPlayer instances (sfx + loop). SettingsBloc promoted to MaterialApp level via BlocProvider + BlocBuilder for reactive theme. AudioService provided via RepositoryProvider so GameBloc and GameScreen can read it from context. GameBloc gains AudioService constructor param and SelectSymbol toggle. GameOverScreen and CompletionScreen each gain puzzle + puzzleRepo params for direct push navigation.

**Tech Stack:** Flutter, flutter_bloc (BlocProvider, BlocBuilder, RepositoryProvider), audioplayers ^6.1.0, Node.js WAV synthesis.

---

## File Map

```
tools/generate_audio.js                                   ← new: Node.js WAV synthesizer
assets/audio/click.wav                                    ← generated: soft sine blip
assets/audio/thud.wav                                     ← generated: low thud
assets/audio/error.wav                                    ← generated: short buzz
assets/audio/complete.wav                                 ← generated: rising chime
assets/audio/bg_music.wav                                 ← generated: 4-bar ambient loop
lib/core/services/audio_service.dart                      ← new: audioplayers wrapper
lib/presentation/bloc/settings/settings_bloc.dart         ← inject AudioService; wire sfx/music toggles
lib/main.dart                                             ← create AudioService + SettingsBloc; RepositoryProvider
lib/presentation/screens/game/game_screen.dart            ← add puzzleRepo; StatefulWidget for music; no title; push screens directly; pause theme toggle
lib/presentation/bloc/game/game_bloc.dart                 ← inject AudioService; SelectSymbol toggle; audio calls
lib/presentation/widgets/number_panel.dart                ← add onLongPress
lib/presentation/screens/home/home_screen.dart            ← add AppBar with theme toggle
lib/presentation/screens/game_over/game_over_screen.dart  ← accept puzzle+repo; two action buttons
lib/presentation/screens/completion/completion_screen.dart ← accept puzzle+repo; two action buttons
lib/presentation/screens/difficulty_select/difficulty_select_screen.dart ← pass puzzleRepo to GameScreen
```

---

## Task 1: Generate Audio Files

**Files:**
- Create: `tools/generate_audio.js`
- Create: `assets/audio/click.wav`, `assets/audio/thud.wav`, `assets/audio/error.wav`, `assets/audio/complete.wav`, `assets/audio/bg_music.wav`

- [ ] **Step 1: Write tools/generate_audio.js**

```javascript
const fs = require('fs');
const path = require('path');

const SAMPLE_RATE = 44100;
const CHANNELS = 1;
const BITS = 16;

function writeWav(filename, samples) {
  const dataLength = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataLength);
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataLength, 4);
  buffer.write('WAVE', 8);
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(CHANNELS, 22);
  buffer.writeUInt32LE(SAMPLE_RATE, 24);
  buffer.writeUInt32LE(SAMPLE_RATE * CHANNELS * BITS / 8, 28);
  buffer.writeUInt16LE(CHANNELS * BITS / 8, 32);
  buffer.writeUInt16LE(BITS, 34);
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataLength, 40);
  for (let i = 0; i < samples.length; i++) {
    buffer.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), 44 + i * 2);
  }
  fs.writeFileSync(filename, buffer);
  console.log(`Written: ${path.basename(filename)} (${(samples.length / SAMPLE_RATE).toFixed(2)}s)`);
}

function makeClick() {
  const n = Math.round(0.12 * SAMPLE_RATE);
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    return 0.4 * Math.exp(-30 * t) * Math.sin(2 * Math.PI * 880 * t);
  });
}

function makeThud() {
  const n = Math.round(0.30 * SAMPLE_RATE);
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    return 0.6 * Math.exp(-12 * t) * Math.sin(2 * Math.PI * 80 * t);
  });
}

function makeError() {
  const n = Math.round(0.25 * SAMPLE_RATE);
  return Array.from({ length: n }, (_, i) => {
    const t = i / SAMPLE_RATE;
    return 0.3 * Math.exp(-8 * t) * Math.sign(Math.sin(2 * Math.PI * 200 * t));
  });
}

function makeComplete() {
  const notes = [523.25, 659.25, 783.99, 1046.50];
  const noteDur = 0.18;
  const total = notes.length * noteDur + 0.3;
  const n = Math.round(total * SAMPLE_RATE);
  const samples = new Array(n).fill(0);
  notes.forEach((freq, idx) => {
    const start = Math.round(idx * noteDur * SAMPLE_RATE);
    const end = Math.round((idx * noteDur + 0.4) * SAMPLE_RATE);
    for (let i = start; i < Math.min(end, n); i++) {
      const t = (i - start) / SAMPLE_RATE;
      samples[i] += 0.35 * Math.exp(-5 * t) * Math.sin(2 * Math.PI * freq * t);
    }
  });
  return samples;
}

function makeBgMusic() {
  const duration = 4.0;
  const n = Math.round(duration * SAMPLE_RATE);
  const samples = new Array(n).fill(0);
  const freqs = [261.63, 293.66, 329.63, 392.00, 440.00];
  const noteDur = duration / freqs.length;
  freqs.forEach((freq, idx) => {
    const start = Math.round(idx * noteDur * SAMPLE_RATE);
    const end = Math.round((idx + 1) * noteDur * SAMPLE_RATE);
    for (let i = start; i < end; i++) {
      const t = (i - start) / SAMPLE_RATE;
      const env = Math.sin(Math.PI * (i - start) / (end - start));
      samples[i] += 0.15 * env * Math.sin(2 * Math.PI * freq * t);
      samples[i] += 0.08 * env * Math.sin(2 * Math.PI * freq * 2 * t);
    }
  });
  return samples;
}

const outDir = path.join(__dirname, '..', 'assets', 'audio');
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

writeWav(path.join(outDir, 'click.wav'), makeClick());
writeWav(path.join(outDir, 'thud.wav'), makeThud());
writeWav(path.join(outDir, 'error.wav'), makeError());
writeWav(path.join(outDir, 'complete.wav'), makeComplete());
writeWav(path.join(outDir, 'bg_music.wav'), makeBgMusic());
```

- [ ] **Step 2: Run generator**

```powershell
node D:\projects\gravity-sudoku\tools\generate_audio.js
```

Expected output:
```
Written: click.wav (0.12s)
Written: thud.wav (0.30s)
Written: error.wav (0.25s)
Written: complete.wav (1.02s)
Written: bg_music.wav (4.00s)
```

- [ ] **Step 3: Commit**

```bash
git -C D:\projects\gravity-sudoku add tools/generate_audio.js assets/audio/
git -C D:\projects\gravity-sudoku commit -m "feat: add audio WAV files via Node.js synthesizer"
```

---

## Task 2: AudioService

**Files:**
- Create: `lib/core/services/audio_service.dart`

- [ ] **Step 1: Write audio_service.dart**

```dart
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  bool _sfxEnabled = true;
  bool _musicEnabled = true;

  Future<void> playClick() => _playSfx('audio/click.wav');
  Future<void> playThud() => _playSfx('audio/thud.wav');
  Future<void> playError() => _playSfx('audio/error.wav');
  Future<void> playComplete() => _playSfx('audio/complete.wav');

  Future<void> _playSfx(String asset) async {
    if (!_sfxEnabled) return;
    await _sfx.play(AssetSource(asset));
  }

  Future<void> startMusic() async {
    if (!_musicEnabled) return;
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.play(AssetSource('audio/bg_music.wav'));
  }

  Future<void> stopMusic() async {
    await _music.stop();
  }

  void setSfxEnabled(bool v) {
    _sfxEnabled = v;
    if (!v) _sfx.stop();
  }

  void setMusicEnabled(bool v) {
    _musicEnabled = v;
    if (!v) {
      _music.stop();
    } else {
      startMusic();
    }
  }

  Future<void> dispose() async {
    await _sfx.dispose();
    await _music.dispose();
  }
}
```

- [ ] **Step 2: Run analyzer**

```powershell
D:\flutter\bin\dart.bat analyze lib/core/services/audio_service.dart
```

Expected: `No issues found.`

- [ ] **Step 3: Commit**

```bash
git -C D:\projects\gravity-sudoku add lib/core/services/audio_service.dart
git -C D:\projects\gravity-sudoku commit -m "feat: add AudioService wrapping audioplayers"
```

---

## Task 3: Promote SettingsBloc + AudioService to App Level

**Files:**
- Modify: `lib/presentation/bloc/settings/settings_bloc.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Update settings_bloc.dart to inject AudioService**

Replace the entire file with:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/audio_service.dart';
import '../../../data/local/prefs/preferences_service.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final PreferencesService _prefs;
  final AudioService _audio;

  SettingsBloc(this._prefs, this._audio)
      : super(SettingsState(
          sfxEnabled: _prefs.sfxEnabled,
          musicEnabled: _prefs.musicEnabled,
          theme: _prefs.selectedTheme,
        )) {
    on<ToggleSfx>((e, emit) async {
      final v = !state.sfxEnabled;
      await _prefs.setSfx(v);
      _audio.setSfxEnabled(v);
      emit(state.copyWith(sfxEnabled: v));
    });
    on<ToggleMusic>((e, emit) async {
      final v = !state.musicEnabled;
      await _prefs.setMusic(v);
      _audio.setMusicEnabled(v);
      emit(state.copyWith(musicEnabled: v));
    });
    on<ChangeTheme>((e, emit) async {
      await _prefs.setTheme(e.theme);
      emit(state.copyWith(theme: e.theme));
    });
  }
}
```

- [ ] **Step 2: Replace main.dart**

Replace the entire file with:

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/audio_service.dart';
import 'core/theme/app_theme.dart';
import 'data/local/database/app_database.dart';
import 'data/local/prefs/preferences_service.dart';
import 'data/repositories/local_puzzle_repository.dart';
import 'data/repositories/local_progress_repository.dart';
import 'data/repositories/memory_puzzle_repository.dart';
import 'data/repositories/memory_progress_repository.dart';
import 'domain/repositories/puzzle_repository.dart';
import 'domain/repositories/progress_repository.dart';
import 'presentation/bloc/settings/settings_bloc.dart';
import 'presentation/bloc/settings/settings_state.dart';
import 'presentation/screens/difficulty_select/difficulty_select_screen.dart';
import 'presentation/screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  late PuzzleRepository puzzleRepo;
  late ProgressRepository progressRepo;
  late PreferencesService prefs;

  if (kIsWeb) {
    puzzleRepo = MemoryPuzzleRepository();
    progressRepo = MemoryProgressRepository();
    prefs = PreferencesService(await SharedPreferences.getInstance());
  } else {
    final db = AppDatabase();
    final localPuzzleRepo = LocalPuzzleRepository(db);
    await _seedPuzzles(localPuzzleRepo);
    puzzleRepo = localPuzzleRepo;
    progressRepo = LocalProgressRepository(db);
    prefs = PreferencesService(await SharedPreferences.getInstance());
  }

  final audioService = AudioService();

  runApp(GravitySudokuApp(
    prefs: prefs,
    audioService: audioService,
    puzzleRepo: puzzleRepo,
    progressRepo: progressRepo,
  ));
}

Future<void> _seedPuzzles(LocalPuzzleRepository repo) async {
  final files = [
    'assets/puzzles/tutorial_4x4.json',
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
  final AudioService audioService;
  final PuzzleRepository puzzleRepo;
  final ProgressRepository progressRepo;

  const GravitySudokuApp({
    super.key,
    required this.prefs,
    required this.audioService,
    required this.puzzleRepo,
    required this.progressRepo,
  });

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AudioService>.value(
      value: audioService,
      child: BlocProvider(
        create: (_) => SettingsBloc(prefs, audioService),
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settings) => MaterialApp(
            title: 'Gravity Sudoku',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.theme == 'dark' ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/',
            onGenerateRoute: (routeSettings) {
              switch (routeSettings.name) {
                case '/':
                  return MaterialPageRoute(builder: (_) => const HomeScreen());
                case '/difficulty':
                  return MaterialPageRoute(
                    builder: (_) => DifficultySelectScreen(puzzleRepo: puzzleRepo),
                  );
                default:
                  return MaterialPageRoute(builder: (_) => const HomeScreen());
              }
            },
          ),
        ),
      ),
    );
  }
}
```

Note: `/completion` and `/game_over` named routes are removed — screens are now pushed directly from GameScreen.

- [ ] **Step 3: Run analyzer**

```powershell
D:\flutter\bin\dart.bat analyze lib/main.dart lib/presentation/bloc/settings/settings_bloc.dart
```

Expected: `No issues found.`

- [ ] **Step 4: Commit**

```bash
git -C D:\projects\gravity-sudoku add lib/main.dart lib/presentation/bloc/settings/settings_bloc.dart
git -C D:\projects\gravity-sudoku commit -m "feat: promote SettingsBloc to app level, provide AudioService via RepositoryProvider"
```

---

## Task 4: GameBloc — SelectSymbol Toggle + Audio Calls

**Files:**
- Modify: `lib/presentation/bloc/game/game_bloc.dart`

- [ ] **Step 1: Replace game_bloc.dart**

```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/symbols.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/utils/position.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/services/gravity_engine.dart';
import '../../../domain/services/hint_service.dart';
import '../../../domain/services/sudoku_validator.dart';
import 'game_event.dart';
import 'game_state.dart';

class GameBloc extends Bloc<GameEvent, GameState> {
  final Puzzle _puzzle;
  final GravityEngine _gravity;
  final SudokuValidator _validator;
  final HintService _hint;
  final AudioService _audio;
  Timer? _timer;
  Timer? _wrongFlashTimer;

  GameBloc({
    required Puzzle puzzle,
    required GravityEngine gravity,
    required SudokuValidator validator,
    required HintService hint,
    required AudioService audio,
  })  : _puzzle = puzzle,
        _gravity = gravity,
        _validator = validator,
        _hint = hint,
        _audio = audio,
        super(GameState.initial(
          puzzle.initialBoard,
          isTutorial: puzzle.difficulty == Difficulty.tutorial,
        )) {
    on<SelectSymbol>(_onSelectSymbol);
    on<PlaceNumber>(_onPlaceNumber);
    on<UndoMove>(_onUndo);
    on<RestartPuzzle>(_onRestart);
    on<RequestHint>(_onHint);
    on<PauseGame>(_onPause);
    on<ResumeGame>(_onResume);
    on<TimerTicked>(_onTick);
    on<WrongFlashCleared>(_onWrongFlashCleared);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed && state.status == GameStatus.playing) add(const TimerTicked());
    });
  }

  void _onSelectSymbol(SelectSymbol event, Emitter<GameState> emit) {
    if (event.symbol == state.selectedSymbol) {
      emit(state.copyWith(clearSymbol: true, clearHint: true));
    } else {
      _audio.playClick();
      emit(state.copyWith(selectedSymbol: event.symbol, clearHint: true));
    }
  }

  void _onPlaceNumber(PlaceNumber event, Emitter<GameState> emit) {
    if (state.status != GameStatus.playing) return;
    final sym = state.selectedSymbol;
    if (sym == null) return;
    final cell = state.board.cellAt(event.row, event.col);
    if (cell.isIceBlock || cell.isFixed) return;

    final value = SymbolSystem.toValue(sym);
    final result =
        _gravity.simulate(state.board, col: event.col, fromRow: event.row);
    final landCell = state.board.cellAt(result.toRow, event.col);
    if (!landCell.isEmpty) return;

    final solutionValue =
        _puzzle.solution.cellAt(result.toRow, event.col).value;
    final isCorrect = solutionValue == value;

    if (!isCorrect && _puzzle.difficulty != Difficulty.tutorial) {
      _audio.playError();
      final newHearts = state.hearts - 1;
      _wrongFlashTimer?.cancel();
      emit(state.copyWith(
        hearts: newHearts,
        wrongFlashCell: Position(result.toRow, event.col),
        status: newHearts <= 0 ? GameStatus.gameOver : GameStatus.playing,
      ));
      _wrongFlashTimer = Timer(const Duration(milliseconds: 600), () {
        if (!isClosed) add(const WrongFlashCleared());
      });
      return;
    }

    final newBoard =
        _gravity.apply(state.board, col: event.col, value: value, result: result);
    final conflicts = _validator.findConflicts(newBoard);
    final newStack = [...state.undoStack, state.board];
    final isComplete = conflicts.isEmpty && _validator.isComplete(newBoard);

    var placedCount = 0;
    for (var r = 0; r < newBoard.size; r++) {
      for (var c = 0; c < newBoard.size; c++) {
        if (newBoard.cellAt(r, c).value == value) placedCount++;
      }
    }
    final symbolExhausted = placedCount >= _puzzle.size;

    if (isComplete) {
      _audio.playComplete();
    } else {
      _audio.playThud();
    }

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
  }

  void _onUndo(UndoMove event, Emitter<GameState> emit) {
    if (state.undoStack.isEmpty) return;
    if (state.undosRemaining <= 0) return;
    final prev = state.undoStack.last;
    final newStack =
        state.undoStack.sublist(0, state.undoStack.length - 1);
    emit(state.copyWith(
      board: prev,
      undoStack: newStack,
      conflicts: _validator.findConflicts(prev),
      undosRemaining: state.undosRemaining - 1,
      clearGravityResult: true,
      clearHint: true,
    ));
  }

  void _onRestart(RestartPuzzle event, Emitter<GameState> emit) {
    _wrongFlashTimer?.cancel();
    emit(GameState.initial(
      state.initialBoard,
      isTutorial: _puzzle.difficulty == Difficulty.tutorial,
    ));
  }

  void _onHint(RequestHint event, Emitter<GameState> emit) {
    final move =
        _hint.suggest(state.board, boardSize: _puzzle.size);
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

  void _onWrongFlashCleared(
      WrongFlashCleared event, Emitter<GameState> emit) {
    if (state.status == GameStatus.gameOver) return;
    emit(state.copyWith(clearWrongFlash: true));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _wrongFlashTimer?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 2: Run analyzer**

```powershell
D:\flutter\bin\dart.bat analyze lib/presentation/bloc/game/game_bloc.dart
```

Expected: `No issues found.`

- [ ] **Step 3: Commit**

```bash
git -C D:\projects\gravity-sudoku add lib/presentation/bloc/game/game_bloc.dart
git -C D:\projects\gravity-sudoku commit -m "feat: SelectSymbol toggle, inject AudioService into GameBloc, audio on game events"
```

---

## Task 5: NumberPanel — onLongPress

**Files:**
- Modify: `lib/presentation/widgets/number_panel.dart`

- [ ] **Step 1: Add onLongPress to GestureDetector**

In `number_panel.dart`, find:

```dart
        return GestureDetector(
          onTap: isDone ? null : () => onSymbolSelected(sym),
          child: AnimatedContainer(
```

Replace with:

```dart
        return GestureDetector(
          onTap: isDone ? null : () => onSymbolSelected(sym),
          onLongPress: isDone ? null : () => onSymbolSelected(sym),
          child: AnimatedContainer(
```

- [ ] **Step 2: Run analyzer**

```powershell
D:\flutter\bin\dart.bat analyze lib/presentation/widgets/number_panel.dart
```

Expected: `No issues found.`

- [ ] **Step 3: Commit**

```bash
git -C D:\projects\gravity-sudoku add lib/presentation/widgets/number_panel.dart
git -C D:\projects\gravity-sudoku commit -m "feat: long press number button triggers select/deselect"
```

---

## Task 6: HomeScreen — Theme Toggle in AppBar

**Files:**
- Modify: `lib/presentation/screens/home/home_screen.dart`

- [ ] **Step 1: Replace home_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../bloc/settings/settings_event.dart';
import '../../bloc/settings/settings_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settings) => Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: Icon(
                settings.theme == 'dark'
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
              onPressed: () => context.read<SettingsBloc>().add(
                    ChangeTheme(settings.theme == 'dark' ? 'light' : 'dark'),
                  ),
            ),
          ],
        ),
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
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/difficulty'),
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Text('Play', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/difficulty'),
                  child: const Text('Daily Challenge'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

```powershell
D:\flutter\bin\dart.bat analyze lib/presentation/screens/home/home_screen.dart
```

Expected: `No issues found.`

- [ ] **Step 3: Commit**

```bash
git -C D:\projects\gravity-sudoku add lib/presentation/screens/home/home_screen.dart
git -C D:\projects\gravity-sudoku commit -m "feat: add theme toggle IconButton to HomeScreen AppBar"
```

---

## Task 7: GameOverScreen — New Constructor + Two Buttons

**Files:**
- Modify: `lib/presentation/screens/game_over/game_over_screen.dart`

- [ ] **Step 1: Replace game_over_screen.dart**

```dart
import 'package:flutter/material.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/repositories/puzzle_repository.dart';
import '../game/game_screen.dart';

class GameOverScreen extends StatelessWidget {
  final Puzzle puzzle;
  final PuzzleRepository puzzleRepo;

  const GameOverScreen({
    super.key,
    required this.puzzle,
    required this.puzzleRepo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Game Over',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You ran out of lives.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('restart'),
              child: const Text('重新開始'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _newLevel(context),
              child: const Text('換一關'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _newLevel(BuildContext context) async {
    final newPuzzle = await puzzleRepo.fetchRandom(
      puzzle.difficulty,
      excludeId: puzzle.id,
    );
    if (newPuzzle == null || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => GameScreen(puzzle: newPuzzle, puzzleRepo: puzzleRepo),
      ),
      (route) => route.isFirst,
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

```powershell
D:\flutter\bin\dart.bat analyze lib/presentation/screens/game_over/game_over_screen.dart
```

Expected: `No issues found.`

- [ ] **Step 3: Commit**

```bash
git -C D:\projects\gravity-sudoku add lib/presentation/screens/game_over/game_over_screen.dart
git -C D:\projects\gravity-sudoku commit -m "feat: game over screen with restart and new level actions"
```

---

## Task 8: CompletionScreen — New Constructor + Two Buttons

**Files:**
- Modify: `lib/presentation/screens/completion/completion_screen.dart`

- [ ] **Step 1: Replace completion_screen.dart**

```dart
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/repositories/puzzle_repository.dart';
import '../game/game_screen.dart';

class CompletionScreen extends StatefulWidget {
  final int stars;
  final int elapsedSeconds;
  final Puzzle puzzle;
  final PuzzleRepository puzzleRepo;

  const CompletionScreen({
    super.key,
    required this.stars,
    required this.elapsedSeconds,
    required this.puzzle,
    required this.puzzleRepo,
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
                const Text(
                  'Puzzle Complete!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Icon(
                      i < widget.stars ? Icons.star : Icons.star_border,
                      color: AppColors.hint,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Time: ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => _continueSameDifficulty(context),
                  child: const Text('繼續相同難度'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('選難度'),
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

  Future<void> _continueSameDifficulty(BuildContext context) async {
    final newPuzzle = await widget.puzzleRepo.fetchRandom(
      widget.puzzle.difficulty,
      excludeId: widget.puzzle.id,
    );
    if (newPuzzle == null || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          puzzle: newPuzzle,
          puzzleRepo: widget.puzzleRepo,
        ),
      ),
      (route) => route.isFirst,
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

```powershell
D:\flutter\bin\dart.bat analyze lib/presentation/screens/completion/completion_screen.dart
```

Expected: `No issues found.`

- [ ] **Step 3: Commit**

```bash
git -C D:\projects\gravity-sudoku add lib/presentation/screens/completion/completion_screen.dart
git -C D:\projects\gravity-sudoku commit -m "feat: completion screen with continue same difficulty and select difficulty actions"
```

---

## Task 9: GameScreen — All Updates + DifficultySelectScreen Fix

**Files:**
- Modify: `lib/presentation/screens/game/game_screen.dart`
- Modify: `lib/presentation/screens/difficulty_select/difficulty_select_screen.dart`

- [ ] **Step 1: Replace game_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/symbols.dart';
import '../../../core/services/audio_service.dart';
import '../../../domain/models/board.dart';
import '../../../domain/models/puzzle.dart';
import '../../../domain/repositories/puzzle_repository.dart';
import '../../../domain/services/gravity_engine.dart';
import '../../../domain/services/hint_service.dart';
import '../../../domain/services/sudoku_validator.dart';
import '../../bloc/game/game_bloc.dart';
import '../../bloc/game/game_event.dart';
import '../../bloc/game/game_state.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../bloc/settings/settings_event.dart';
import '../../bloc/settings/settings_state.dart';
import '../../widgets/game_controls.dart';
import '../../widgets/heart_row.dart';
import '../../widgets/number_panel.dart';
import '../../widgets/sudoku_grid.dart';
import '../../widgets/tutorial_overlay.dart';
import '../completion/completion_screen.dart';
import '../game_over/game_over_screen.dart';

class GameScreen extends StatelessWidget {
  final Puzzle puzzle;
  final PuzzleRepository puzzleRepo;

  const GameScreen({
    super.key,
    required this.puzzle,
    required this.puzzleRepo,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => GameBloc(
        puzzle: puzzle,
        gravity: GravityEngine(),
        validator: SudokuValidator(),
        hint: HintService(gravity: GravityEngine(), validator: SudokuValidator()),
        audio: ctx.read<AudioService>(),
      ),
      child: _GameView(puzzle: puzzle, puzzleRepo: puzzleRepo),
    );
  }
}

class _GameView extends StatefulWidget {
  final Puzzle puzzle;
  final PuzzleRepository puzzleRepo;

  const _GameView({required this.puzzle, required this.puzzleRepo});

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> {
  late AudioService _audio;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _audio = context.read<AudioService>();
      _audio.startMusic();
    }
  }

  @override
  void dispose() {
    _audio.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameBloc, GameState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) async {
        if (state.status == GameStatus.completed) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CompletionScreen(
                stars: state.stars,
                elapsedSeconds: state.elapsedSeconds,
                puzzle: widget.puzzle,
                puzzleRepo: widget.puzzleRepo,
              ),
            ),
          );
        } else if (state.status == GameStatus.gameOver) {
          final result = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => GameOverScreen(
                puzzle: widget.puzzle,
                puzzleRepo: widget.puzzleRepo,
              ),
            ),
          );
          if (result == 'restart' && context.mounted) {
            context.read<GameBloc>().add(const RestartPuzzle());
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: () => _showPauseMenu(context),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  if (widget.puzzle.difficulty != Difficulty.tutorial)
                    BlocBuilder<GameBloc, GameState>(
                      buildWhen: (p, c) => p.hearts != c.hearts,
                      builder: (context, state) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: HeartRow(hearts: state.hearts),
                      ),
                    ),
                  _TimerRow(),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: BlocBuilder<GameBloc, GameState>(
                        buildWhen: (p, c) =>
                            p.board != c.board ||
                            p.conflicts != c.conflicts ||
                            p.hintCell != c.hintCell ||
                            p.wrongFlashCell != c.wrongFlashCell,
                        builder: (context, state) => SudokuGrid(
                          board: state.board,
                          conflicts: state.conflicts,
                          hintCell: state.hintCell,
                          wrongFlashCell: state.wrongFlashCell,
                          onCellTap: (row, col) {
                            context.read<GameBloc>().add(PlaceNumber(row, col));
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  BlocBuilder<GameBloc, GameState>(
                    buildWhen: (p, c) =>
                        p.undoStack.length != c.undoStack.length ||
                        p.undosRemaining != c.undosRemaining,
                    builder: (context, state) => GameControls(
                      undosRemaining: state.undosRemaining,
                      onUndo: () =>
                          context.read<GameBloc>().add(const UndoMove()),
                      onHint: () =>
                          context.read<GameBloc>().add(const RequestHint()),
                      onClear: () {},
                    ),
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<GameBloc, GameState>(
                    buildWhen: (p, c) =>
                        p.selectedSymbol != c.selectedSymbol ||
                        p.board != c.board,
                    builder: (context, state) => NumberPanel(
                      boardSize: widget.puzzle.size,
                      selectedSymbol: state.selectedSymbol,
                      remainingCounts: _computeRemaining(
                          state.board, widget.puzzle.size),
                      onSymbolSelected: (sym) =>
                          context.read<GameBloc>().add(SelectSymbol(sym)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (widget.puzzle.tutorialStep != null)
              TutorialOverlay(message: widget.puzzle.tutorialStep!),
          ],
        ),
      ),
    );
  }

  void _showPauseMenu(BuildContext context) {
    context.read<GameBloc>().add(const PauseGame());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocBuilder<SettingsBloc, SettingsState>(
        builder: (ctx, settings) => AlertDialog(
          title: const Text('Paused'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Dark mode'),
                value: settings.theme == 'dark',
                onChanged: (v) => ctx.read<SettingsBloc>().add(
                      ChangeTheme(v ? 'dark' : 'light'),
                    ),
              ),
            ],
          ),
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
      ),
    );
  }

  Map<String, int> _computeRemaining(Board board, int size) {
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

- [ ] **Step 2: Update DifficultySelectScreen to pass puzzleRepo to GameScreen**

In `difficulty_select_screen.dart`, find:

```dart
      nav.push(MaterialPageRoute(builder: (_) => GameScreen(puzzle: puzzle)));
```

Replace with:

```dart
      nav.push(MaterialPageRoute(builder: (_) => GameScreen(puzzle: puzzle, puzzleRepo: puzzleRepo)));
```

- [ ] **Step 3: Run full analyzer**

```powershell
D:\flutter\bin\dart.bat analyze lib/
```

Expected: `No issues found.`

- [ ] **Step 4: Commit**

```bash
git -C D:\projects\gravity-sudoku add lib/presentation/screens/game/game_screen.dart lib/presentation/screens/difficulty_select/difficulty_select_screen.dart
git -C D:\projects\gravity-sudoku commit -m "feat: game screen with music lifecycle, pause theme toggle, direct navigation to game-over/completion screens"
```

---

## Self-Review

- **Spec coverage:**
  1. Remove Level title from AppBar ✓ — AppBar has no `title:` in new game_screen.dart
  2. Game Over navigation: 重新開始 (pop 'restart' → GameBloc.RestartPuzzle) + 換一關 (pushAndRemoveUntil with new puzzle) ✓
  3. Completion navigation: 繼續相同難度 (pushAndRemoveUntil with new puzzle) + 選難度 (popUntil isFirst) ✓
  4. Long press selects/deselects (same toggle logic as tap) ✓
  5. Audio system: AudioService + 5 WAV files + GameBloc calls + SettingsBloc wiring + music lifecycle ✓
  6. Theme toggle: HomeScreen AppBar IconButton + Pause menu SwitchListTile ✓
- **Placeholders:** None — all steps contain complete, runnable code.
- **Type consistency:** `AudioService` passed via constructor in GameBloc (Task 4) and read via `ctx.read<AudioService>()` in GameScreen (Task 9). `PuzzleRepository puzzleRepo` added to GameScreen, GameOverScreen, CompletionScreen consistently. `fetchRandom(difficulty, excludeId: puzzle.id)` matches the signature added in the prior session.
