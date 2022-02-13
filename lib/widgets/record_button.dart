import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:provider/provider.dart';
import 'package:voice_outliner/consts.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/state/player_state.dart';

/// How long does the user have to hold down for it to be considered a "hold"?
const holdThreshold = 750;

class RecordButton extends StatefulWidget {
  const RecordButton({Key? key}) : super(key: key);

  @override
  _RecordButtonState createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  Offset offset = const Offset(0, 0);
  final Stopwatch _stopwatch = Stopwatch();

  Color computeShadowColor(double dy) {
    Color a = const Color.fromRGBO(169, 129, 234, 0.6);
    Color b = const Color.fromRGBO(248, 82, 150, 0.6);
    double t = (dy.abs() / MediaQuery.of(context).size.height);
    return Color.lerp(a, b, t)!;
  }

  _stopRecord(_) async {
    final playerState = context.read<PlayerModel>().playerState;
    if (_stopwatch.elapsedMilliseconds > holdThreshold ||
        playerState == PlayerState.recordingContinuously) {
      _stopwatch.stop();
      _stopwatch.reset();
      int magnitude = max(
          ((-1 * offset.dy / MediaQuery.of(context).size.height) * 100).toInt(),
          0);
      await context.read<NotesModel>().stopRecording(magnitude);
    } else {
      // If finger lifted in time, this was a tap not a hold. Keep recording
      context.read<PlayerModel>().setContinuousRecording();
    }
  }

  _stopRecord0() {
    _stopRecord(null);
  }

  _startRecord(_) async {
    final playerState = context.read<PlayerModel>().playerState;
    if (playerState == PlayerState.ready) {
      _stopwatch.start();
      await context.read<NotesModel>().startRecording();
    }
  }

  _playEffect(LongPressDownDetails d) {
    Vibrate.feedback(FeedbackType.impact);
    setState(() {
      offset = d.localPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState =
        context.select<PlayerModel, PlayerState>((p) => p.playerState);
    return GestureDetector(
        onTapDown: _startRecord,
        onTapUp: _stopRecord,
        onLongPressDown: _playEffect,
        onLongPressUp: _stopRecord0,
        onPanEnd: _stopRecord,
        onPanDown: _startRecord,
        onLongPressMoveUpdate: (LongPressMoveUpdateDetails d) {
          setState(() {
            offset = d.localPosition;
          });
        },
        onPanUpdate: (DragUpdateDetails d) {
          setState(() {
            offset = d.localPosition;
          });
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
                              ? "recording"
                              : "hold to record",
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15.0),
                    )
                  ])),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                      color: playerState == PlayerState.recordingContinuously
                          ? warmRed.withOpacity(0.5)
                          : const Color.fromRGBO(156, 103, 241, .36),
                      blurRadius: 18.0,
                      spreadRadius: 0.0,
                      offset: const Offset(0, 7)),
                  if (playerState == PlayerState.recording)
                    BoxShadow(
                        color: computeShadowColor(offset.dy),
                        blurRadius: 120.0,
                        spreadRadius: 120.0,
                        offset: offset + const Offset(-100, -95))
                ],
                borderRadius: BorderRadius.circular(100.0),
                color: playerState == PlayerState.recordingContinuously
                    ? warmRed
                    : classicPurple,
              )),
        ));
  }
}
