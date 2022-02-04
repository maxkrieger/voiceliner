import 'package:flutter/material.dart';
import 'package:provider/src/provider.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/state/player_state.dart';
import 'package:voice_outliner/views/notes_view.dart';

import '../consts.dart';
import 'note_item.dart';

class ResultNote extends StatefulWidget {
  final Note note;
  final bool truncate;
  const ResultNote({Key? key, required this.note, this.truncate = false})
      : super(key: key);

  @override
  _ResultNoteState createState() => _ResultNoteState();
}

class _ResultNoteState extends State<ResultNote> {
  bool playing = false;
  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 0,
        clipBehavior: Clip.hardEdge,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        color: widget.note.isComplete
            ? const Color.fromRGBO(229, 229, 229, 0.3)
            : computeColor(widget.note.color).withOpacity(0.2),
        margin: const EdgeInsets.all(5.0),
        child: ListTile(
            leading: widget.note.filePath != null
                ? IconButton(
                    tooltip: "play note",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      final playerModel = context.read<PlayerModel>();
                      if (playing) {
                        setState(() {
                          playing = false;
                        });
                        playerModel.stopPlaying();
                      } else {
                        setState(() {
                          playing = true;
                        });
                        playerModel.playNote(widget.note, () {
                          setState(() {
                            playing = false;
                          });
                        });
                      }
                    },
                    color: classicPurple,
                    icon: playing
                        ? const Icon(Icons.stop_circle_outlined)
                        : const Icon(Icons.play_circle))
                : const Icon(
                    Icons.text_fields,
                    semanticLabel: "text note",
                    color: classicPurple,
                  ),
            onTap: () => Navigator.pushNamed(context, "/notes",
                arguments: NotesViewArgs(widget.note.outlineId,
                    scrollToNoteId: widget.note.id)),
            title: Text(
              widget.note.transcript ?? widget.note.infoString,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  decoration: widget.note.isComplete
                      ? TextDecoration.lineThrough
                      : null),
            )));
  }
}
