import 'dart:io';

import 'package:binder/binder.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PlayerState {
  final int? playingIdx;
  final bool isPlaying;
  final bool isRecording;
  final bool isReady;
  const PlayerState(
      {this.playingIdx,
      required this.isReady,
      required this.isPlaying,
      required this.isRecording});
}

final playerLogicRef = LogicRef((scope) => PlayerLogic(scope));
final playerStateRef = StateRef<PlayerState>(
    const PlayerState(isPlaying: false, isRecording: false, isReady: false));

class InternalPlayerState {
  FlutterSoundPlayer player;
  FlutterSoundRecorder recorder;
  late Directory docsDirectory;
  late Directory recordingsDirectory;
  InternalPlayerState(this.player, this.recorder);
}

final internalPlayerRef =
    StateRef(InternalPlayerState(FlutterSoundPlayer(), FlutterSoundRecorder()));

class PlayerLogic with Logic implements Loadable, Disposable {
  PlayerLogic(this.scope);

  InternalPlayerState get _internalPlayer => read(internalPlayerRef);

  @override
  final Scope scope;

  @override
  void dispose() {
    _internalPlayer.recorder.closeAudioSession();
    _internalPlayer.player.closeAudioSession();
  }

  @override
  Future<void> load() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException("Could not get microphone permission");
    }
    _internalPlayer.docsDirectory = await getApplicationDocumentsDirectory();
    _internalPlayer.recordingsDirectory =
        await Directory("${_internalPlayer.docsDirectory.path}/recordings")
            .create(recursive: true);
    // TODO: play from headphones IF AVAILABLE
    await _internalPlayer.player.openAudioSession();
    await _internalPlayer.recorder.openAudioSession();
    write(playerStateRef,
        const PlayerState(isReady: true, isPlaying: false, isRecording: false));
  }
}
