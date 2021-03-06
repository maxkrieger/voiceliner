import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart' as sentry;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/repositories/ios_speech_recognizer.dart';

enum PlayerState {
  notLoaded,
  noPermission,
  notReady,
  error,
  ready,
  playing,
  recording,
  recordingContinuously
}

Future<Directory> getRecordingsDir() async {
  final docsDirectory = await getApplicationDocumentsDirectory();
  return Directory("${docsDirectory.path}/recordings");
}

class PlayerModel extends ChangeNotifier {
  final _player = FlutterSoundPlayer(logLevel: Level.warning);
  final _recorder = FlutterSoundRecorder(logLevel: Level.warning);
  late Directory recordingsDirectory;
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
    if (note.filePath != null) {
      playerState = PlayerState.playing;
      await _player.startPlayer(
          codec: Codec.aacADTS,
          fromURI: getPathFromFilename(note.filePath!),
          whenFinished: () {
            playerState = PlayerState.ready;
            onDone();
          });
    }
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
    if (note.filePath != null) {
      await _recorder.startRecorder(
          codec: Codec.aacADTS,
          toFile: getPathFromFilename(note.filePath!),
          sampleRate: 44100,
          bitRate: 128000);
      // If not already flagged as continuous
      if (playerState != PlayerState.recordingContinuously) {
        playerState = PlayerState.recording;
      }
      notifyListeners();
    }
  }

  void setContinuousRecording() async {
    playerState = PlayerState.recordingContinuously;
    notifyListeners();
  }

  Future<Duration?> stopRecording({Note? note}) async {
    playerState = PlayerState.ready;
    notifyListeners();
    // This delay prevents cutoff
    await Future.delayed(const Duration(milliseconds: 300));
    await _recorder.stopRecorder();
    if (note == null) {
      return null;
    }
    if (note.filePath != null) {
      final duration = await flutterSoundHelper
          .duration(getPathFromFilename(note.filePath!));
      return duration;
    }
    return null;
  }

  Future<void> tryPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return;
    }
    if (Platform.isIOS) {
      final txStatus = await tryTxPermissionIOS();
      if (!txStatus) {
        return;
      }
    }
    await load();
  }

  // Attempt to warm up cache
  Future<void> makeDummyRecording() async {
    final tempDir = await getTemporaryDirectory();
    await _recorder.startRecorder(
        codec: Codec.aacADTS,
        toFile: "${tempDir.path}/tmp.aac",
        sampleRate: 44100,
        bitRate: 128000);
    await Future.delayed(const Duration(milliseconds: 200));
    await _recorder.stopRecorder();
  }

  Future<void> load() async {
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Load player", timestamp: DateTime.now()));
    recordingsDirectory = await getRecordingsDir();
    recordingsDirectory.create(recursive: true);
    if (playerState == PlayerState.notLoaded) {
      playerState = PlayerState.noPermission;
      notifyListeners();
    }
    final granted = await Permission.microphone.isGranted;
    if (granted) {
      playerState = PlayerState.notReady;
      try {
        // Initing recorder before player means bluetooth works properly
        await _recorder.openAudioSession(
            audioFlags: outputToSpeaker | allowBlueToothA2DP | allowAirPlay);
        await _player.openAudioSession(
            category: SessionCategory.playAndRecord,
            mode: SessionMode.modeSpokenAudio,
            focus: AudioFocus.requestFocusAndStopOthers);
        playerState = PlayerState.ready;
        notifyListeners();
        await makeDummyRecording();
      } catch (e, st) {
        playerState = PlayerState.error;
        notifyListeners();
        await sentry.Sentry.captureException(e, stackTrace: st);
      }
    }
  }
}
