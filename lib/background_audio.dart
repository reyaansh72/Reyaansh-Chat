import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundAudioController {
  BackgroundAudioController._();

  static final BackgroundAudioController instance = BackgroundAudioController._();

  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> selectedPathNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> selectedNameNotifier = ValueNotifier<String>('');

  bool _isInitialized = false;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _player.setReleaseMode(ReleaseMode.loop);
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('backgroundMusicEnabled') ?? false;
    final path = prefs.getString('backgroundMusicPath') ?? '';
    final name = prefs.getString('backgroundMusicName') ?? '';

    enabledNotifier.value = enabled;
    selectedPathNotifier.value = path;
    selectedNameNotifier.value = name;
    _isInitialized = true;

    if (enabled && path.isNotEmpty) {
      await _playSelected();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    enabledNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backgroundMusicEnabled', enabled);

    if (!enabled) {
      await _player.pause();
      _isPlaying = false;
      return;
    }

    if (selectedPathNotifier.value.isNotEmpty) {
      await _playSelected();
    }
  }

  Future<String?> pickAndSetMusic() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backgroundMusicPath', path);
    await prefs.setString('backgroundMusicName', file.name);

    selectedPathNotifier.value = path;
    selectedNameNotifier.value = file.name;

    if (enabledNotifier.value) {
      await _playSelected();
    }

    return path;
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  Future<void> _playSelected() async {
    final path = selectedPathNotifier.value;
    if (path.isEmpty || !enabledNotifier.value) {
      await _player.pause();
      _isPlaying = false;
      return;
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _player.play(DeviceFileSource(path));
      } else {
        await _player.play(DeviceFileSource(path));
      }
      _isPlaying = true;
    } catch (_) {
      _isPlaying = false;
    }
  }
}
