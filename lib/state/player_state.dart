import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart' as sentry;
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/repositories/speech_recognizer.dart';

enum PlayerState {
  notLoaded,
  noPermission,
  notReady,
  error,
  ready,
  playing,
  recording,
  processing
}

class PlayerModel extends ChangeNotifier {
  final _player = FlutterSoundPlayer(logLevel: Level.warning);
  final _recorder = FlutterSoundRecorder(logLevel: Level.warning);
  final speechRecognizer = SpeechRecognizer();
  late Directory recordingsDirectory;
  late Directory docsDirectory;
  PlayerState _playerState = PlayerState.notLoaded;

  PlayerState get playerState => _playerState;
  set playerState(PlayerState state) {
    _playerState = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _recorder.closeAudioSession();
    _player.closeAudioSession();
    super.dispose();
  }

  Future<void> playNote(Note note, onDone) async {
    playerState = PlayerState.playing;
    await _player.startPlayer(
        codec: Codec.aacADTS,
        fromURI: getPathFromFilename(note.filePath),
        whenFinished: () {
          playerState = PlayerState.ready;
          onDone();
        });
  }

  Future<void> stopPlaying() async {
    await _player.stopPlayer();
    playerState = PlayerState.ready;
  }

  String getPathFromFilename(String fileName) {
    final path = "${recordingsDirectory.path}/$fileName";
    return path;
  }

  Future<void> startRecording(Note note) async {
    await _recorder.startRecorder(
        codec: Codec.aacADTS,
        toFile: getPathFromFilename(note.filePath),
        sampleRate: 44100,
        bitRate: 128000);
    playerState = PlayerState.recording;
  }

  Future<Duration?> stopRecording({Note? note}) async {
    await _recorder.stopRecorder();
    if (note == null) {
      return null;
    }
    final duration =
        await flutterSoundHelper.duration(getPathFromFilename(note.filePath));
    return duration;
  }

  Future<void> tryPermission() async {
    final status = await Permission.microphone.request();
    if (status == PermissionStatus.granted) {
      await load();
    }
  }

  Future<void> load() async {
    docsDirectory = await getApplicationDocumentsDirectory();
    recordingsDirectory = await Directory("${docsDirectory.path}/recordings")
        .create(recursive: true);
    if (playerState == PlayerState.notLoaded) {
      playerState = PlayerState.noPermission;
      notifyListeners();
    }
    final granted = await Permission.microphone.isGranted;
    if (granted) {
      playerState = PlayerState.notReady;
      try {
        // TODO: play from headphones IF AVAILABLE
        await _player.openAudioSession();
        await _recorder.openAudioSession();
        await speechRecognizer.init();
        playerState = PlayerState.ready;
      } catch (e, st) {
        playerState = PlayerState.error;
        await sentry.Sentry.captureException(e, stackTrace: st);
      }
    }
  }
}
