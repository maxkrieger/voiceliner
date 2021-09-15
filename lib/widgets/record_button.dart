import 'package:binder/binder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/state/player_state.dart';

class RecordButton extends StatefulWidget {
  const RecordButton({Key? key}) : super(key: key);

  @override
  _RecordButtonState createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  @override
  Widget build(BuildContext context) {
    final playerState = context.watch(playerStateRef);
    return GestureDetector(
        onTapDown: (_) {
          context.use(notesLogicRef).startRecording();
          HapticFeedback.mediumImpact();
          Feedback.forTap(context);
        },
        onTapUp: (_) {
          context.use(notesLogicRef).stopRecording();
        },
        onVerticalDragEnd: (_) {
          context.use(notesLogicRef).stopRecording();
        },
        child: AnimatedOpacity(
            duration: const Duration(milliseconds: 100),
            opacity: playerState == PlayerState.ready ||
                    playerState == PlayerState.recording
                ? 1.0
                : 0.0,
            child: AnimatedContainer(
                curve: Curves.bounceInOut,
                duration: const Duration(milliseconds: 100),
                child: Text(
                  playerState == PlayerState.recording
                      ? "recording"
                      : "hold to record",
                  style: const TextStyle(color: Colors.white),
                ),
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 50.0),
                decoration: BoxDecoration(
                  boxShadow: const [
                    BoxShadow(
                        color: Color.fromRGBO(169, 129, 234, 0.8),
                        blurRadius: 3.0,
                        spreadRadius: 3.0,
                        offset: Offset(0, 3))
                  ],
                  borderRadius: BorderRadius.circular(100.0),
                  color: const Color.fromRGBO(169, 129, 234, 0.9),
                ))));
  }
}
