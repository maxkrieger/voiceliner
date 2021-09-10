import 'dart:io';

import 'package:binder/binder.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

final playerLogicRef = LogicRef((scope) => PlayerLogic(scope));
final playerReadyRef = StateRef(false);

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
    _internalPlayer.docsDirectory = await getApplicationDocumentsDirectory();
    _internalPlayer.recordingsDirectory =
        await Directory("${_internalPlayer.docsDirectory.path}/recordings")
            .create(recursive: true);
    // TODO: play from headphones IF AVAILABLE
    await _internalPlayer.player.openAudioSession();
    await _internalPlayer.recorder.openAudioSession();
    write(playerReadyRef, true);
  }
}
