import 'package:binder/binder.dart';
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
    return Card(
        child: ListTile(
      title: Text(note.id),
      onTap: () => context.use(notesLogicRef).playNote(note),
    ));
  }
}
