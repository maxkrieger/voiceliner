import 'dart:io';

import 'package:audio_session/audio_session.dart';
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
  Duration currentDuration = const Duration(milliseconds: 0);
  AudioSession? _session;

  PlayerState get playerState => _playerState;
  set playerState(PlayerState state) {
    _playerState = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  Future<void> playNote(Note note, onDone) async {
    if (note.filePath != null) {
      playerState = PlayerState.playing;
      await _player.startPlayer(
          codec:
              note.filePath!.endsWith("aac") ? Codec.aacADTS : Codec.pcm16WAV,
          fromURI: getPathFromFilename(note.filePath!),
          sampleRate: 44100,
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
    if (note.filePath != null && playerState != PlayerState.recording) {
      await _session!.setActive(true);
      await _recorder.startRecorder(
          codec: Platform.isIOS ? Codec.aacADTS : Codec.pcm16WAV,
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

  Future<void> stopRecording() async {
    playerState = PlayerState.ready;
    notifyListeners();
    await _recorder.stopRecorder();
    await _session!.setActive(false);
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

  // Attempt to warm up cache. Takes a while to start recorder otherwise.
  Future<void> makeDummyRecording() async {
    await _session!.setActive(true);
    final tempDir = await getTemporaryDirectory();
    await _recorder.startRecorder(
        codec: Codec.aacADTS,
        toFile: "${tempDir.path}/tmp.aac",
        sampleRate: 44100,
        bitRate: 128000);
    await Future.delayed(const Duration(milliseconds: 200));
    await _recorder.stopRecorder();
    await _session!.setActive(false);
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
        await _recorder.openRecorder();
        _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
        _recorder.onProgress?.listen((event) {
          currentDuration = event.duration;
        });
        await _player.openPlayer();

        _session = await AudioSession.instance;
        // https://github.com/Canardoux/flutter_sound/issues/868#issuecomment-1081063748
        await _session!.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
                  AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
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
