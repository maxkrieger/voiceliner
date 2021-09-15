import 'package:binder/binder.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:voice_outliner/state/notes_state.dart';

class NoteItem extends StatefulWidget {
  final int num;
  const NoteItem({Key? key, required this.num}) : super(key: key);

  @override
  _NoteItemState createState() => _NoteItemState();
}

class _NoteItemState extends State<NoteItem> {
  @override
  Widget build(BuildContext context) {
    final note = context.watch(notesRef.select((state) => state[widget.num]));
    assert(note.index == widget.num);
    final isCurrent =
        context.watch(currentlyPlayingOrRecordingRef.select((state) {
      return state != null && note.id == state.id;
    }));
    final depth = context.watch(notesRef.select((notes) {
      int getDepth(String? id) {
        if (id != null) {
          final predecessor = notes.firstWhere((element) => element.id == id);
          return 1 + getDepth(predecessor.parentNoteId);
        }
        return 0;
      }

      final d = getDepth(notes[widget.num].parentNoteId);
      return d;
    }));
    return Dismissible(
        confirmDismiss: (direction) async {
          if (note.index == 0) {
            return false;
          }
          if (direction == DismissDirection.startToEnd) {
            context.use(notesLogicRef).indentNote(note);
          } else if (direction == DismissDirection.endToStart) {
            context.use(notesLogicRef).outdentNote(note);
          }
        },
        background: Container(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            child: Align(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                  SizedBox(width: 20.0),
                  Icon(Icons.arrow_forward)
                ]))),
        secondaryBackground: Container(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            child: Align(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                  Icon(Icons.arrow_back),
                  SizedBox(width: 20.0),
                ]))),
        key: Key("dismissable-${note.id}"),
        child: Card(
            margin: EdgeInsets.only(top: 10.0, left: 30.0 * depth, right: 10.0),
            child: ListTile(
              selected: isCurrent,
              selectedTileColor: Colors.deepPurpleAccent,
              title: Text(note.id),
              subtitle: Text(
                  note.duration != null ? "${note.duration!.inSeconds}s" : ""),
              onTap: () => context.use(notesLogicRef).playNote(note),
            )));
  }
}
