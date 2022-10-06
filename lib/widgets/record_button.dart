import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:provider/provider.dart';
import 'package:voice_outliner/consts.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/state/player_state.dart';

/// How long does the user have to hold down for it to be considered a "hold"?
const holdThreshold = 500;

class RecordButton extends StatefulWidget {
  const RecordButton({Key? key}) : super(key: key);

  @override
  _RecordButtonState createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  Offset offset = const Offset(0, 0);
  bool inCancelZone = false;

  Color computeShadowColor(double dy) {
    Color a = const Color.fromRGBO(169, 129, 234, 0.6);
    Color b = const Color.fromRGBO(248, 82, 150, 0.6);
    double t = (dy.abs() / MediaQuery.of(context).size.height);
    return Color.lerp(a, b, t)!;
  }

  _stopRecord(_) async {
    if (inCancelZone) {
      context.read<NotesModel>().cancelRecording();
      setState(() {
        inCancelZone = false;
      });
    } else {
      int magnitude = max(
          ((-1 * offset.dy / MediaQuery.of(context).size.height) * 100).toInt(),
          0);
      await context.read<NotesModel>().stopRecording(magnitude);
    }
  }

  _stopRecord0() {
    _stopRecord(null);
  }

  // Treat record button as stop/start
  _tappedUp(_) {
    final playerState = context.read<PlayerModel>().playerState;
    if (playerState == PlayerState.recordingContinuously) {
      context.read<NotesModel>().stopRecording(0);
    } else {
      context.read<PlayerModel>().setContinuousRecording();
    }
  }

  _startRecord(_) async {
    final playerState = context.read<PlayerModel>().playerState;
    if (playerState == PlayerState.ready) {
      await context.read<NotesModel>().startRecording();
    }
  }

  _playEffect(LongPressDownDetails d) {
    Vibrate.feedback(FeedbackType.impact);
    setState(() {
      offset = d.localPosition;
    });
  }

  _updateOffset(Offset localPosition, Offset globalPosition) {
    final screenWidth = MediaQuery.of(context).size.width;
    final deletionMargin = screenWidth * 0.05;
    setState(() {
      offset = localPosition;
      inCancelZone = globalPosition.dx < deletionMargin ||
          globalPosition.dx > screenWidth - deletionMargin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState =
        context.select<PlayerModel, PlayerState>((p) => p.playerState);
    return GestureDetector(
        // For both taps and holds
        onTapDown: _startRecord,
        // For taps to do continuous recording
        onTapUp: _tappedUp,
        // Lets you play the vibrate, for some reason can't do it on tap down
        onLongPressDown: _playEffect,
        // For slow releases
        onLongPressUp: _stopRecord0,
        // For release of fast swipes
        onPanEnd: _stopRecord,
        // For slow swipes up
        onLongPressMoveUpdate: (LongPressMoveUpdateDetails d) {
          _updateOffset(d.localPosition, d.globalPosition);
        },
        // For fast swipes up
        onPanUpdate: (DragUpdateDetails d) {
          _updateOffset(d.localPosition, d.globalPosition);
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: playerState == PlayerState.ready ||
                  playerState == PlayerState.recording ||
                  playerState == PlayerState.recordingContinuously
              ? 1.0
              : 0.0,
          child: AnimatedContainer(
              width: 200,
              height: 75,
              curve: Curves.bounceInOut,
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                      color: inCancelZone
                          ? warningRed
                          : playerState == PlayerState.recordingContinuously
                              ? warmRed.withOpacity(0.5)
                              : const Color.fromRGBO(156, 103, 241, .36),
                      blurRadius: 18.0,
                      spreadRadius: 0.0,
                      offset: const Offset(0, 7)),
                  if (playerState == PlayerState.recording)
                    BoxShadow(
                        color: inCancelZone
                            ? warningRed
                            : computeShadowColor(offset.dy),
                        blurRadius: 120.0,
                        spreadRadius: 120.0,
                        offset: offset + const Offset(-100, -95))
                ],
                borderRadius: BorderRadius.circular(100.0),
                color: inCancelZone
                    ? warningRed
                    : playerState == PlayerState.recordingContinuously
                        ? warmRed
                        : classicPurple,
              ),
              child: Center(
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    if (playerState != PlayerState.recording) ...[
                      Icon(
                          playerState == PlayerState.recordingContinuously
                              ? Icons.stop
                              : Icons.mic,
                          color: Colors.white),
                      const SizedBox(
                        width: 10.0,
                      )
                    ],
                    Text(
                      playerState == PlayerState.recordingContinuously
                          ? "tap to stop"
                          : playerState == PlayerState.recording
                              ? (inCancelZone
                                  ? "release to cancel"
                                  : "recording")
                              : "hold to record",
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15.0),
                    )
                  ]))),
        ));
  }
}
