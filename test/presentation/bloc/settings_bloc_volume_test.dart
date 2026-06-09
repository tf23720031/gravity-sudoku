import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_sudoku/core/services/audio_service.dart';
import 'package:gravity_sudoku/data/local/prefs/preferences_service.dart';
import 'package:gravity_sudoku/presentation/bloc/settings/settings_bloc.dart';
import 'package:gravity_sudoku/presentation/bloc/settings/settings_event.dart';
import 'package:gravity_sudoku/presentation/bloc/settings/settings_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsBloc volume', () {
    late SettingsBloc bloc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PreferencesService(await SharedPreferences.getInstance());
      bloc = SettingsBloc(prefs, AudioService());
    });

    tearDown(() => bloc.close());

    test('initial musicVolume is 0.8', () {
      expect(bloc.state.musicVolume, closeTo(0.8, 0.001));
    });

    test('initial sfxVolume is 1.0', () {
      expect(bloc.state.sfxVolume, closeTo(1.0, 0.001));
    });

    test('ChangeMusicVolume updates state', () async {
      bloc.add(const ChangeMusicVolume(0.5));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.musicVolume, closeTo(0.5, 0.001));
    });

    test('ChangeSfxVolume updates state', () async {
      bloc.add(const ChangeSfxVolume(0.3));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.sfxVolume, closeTo(0.3, 0.001));
    });
  });
}
