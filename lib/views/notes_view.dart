import 'package:binder/binder.dart';
import 'package:flutter/material.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/widgets/note_item.dart';
import 'package:voice_outliner/widgets/record_button.dart';

class NotesViewWrapper extends StatelessWidget {
  final String outlineId;
  const NotesViewWrapper({Key? key, required this.outlineId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BinderScope(
        overrides: [
          notesLogicRef.overrideWith((scope) => NotesLogic(scope, outlineId))
        ],
        child: LogicLoader(
          refs: [notesLogicRef],
          builder: (ctx, loading, child) {
            if (loading) {
              // TODO: black screen
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            return NotesView(outlineId: outlineId);
          },
        ));
  }
}

class NotesView extends StatefulWidget {
  final String outlineId;
  const NotesView({Key? key, required this.outlineId}) : super(key: key);

  @override
  _NotesViewState createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  @override
  Widget build(BuildContext context) {
    final currentOutlineName = context.watch(
        currentOutlineRef.select((state) => state != null ? state.name : ""));
    final noteCount = context.watch(notesRef.select((state) => state.length));
    return Scaffold(
      appBar: AppBar(title: Text(currentOutlineName)),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 150),
        shrinkWrap: true,
        itemBuilder: (_, int idx) => NoteItem(key: Key("note-$idx"), num: idx),
        itemCount: noteCount,
      ),
      floatingActionButton: const RecordButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
