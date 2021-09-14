import 'package:binder/binder.dart';
import 'package:flutter/material.dart';
import 'package:voice_outliner/state/notes_state.dart';

class NotesView extends StatefulWidget {
  final String outlineId;
  const NotesView({Key? key, required this.outlineId}) : super(key: key);

  @override
  _NotesViewState createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  Widget _buildNote(BuildContext ctx, int num) {
    final note = context.watch(notesRef.select((state) => state[num]));
    return Card(child: ListTile(title: Text(note.id)));
  }

  Widget _buildBody() {
    final notesCount = context.watch(notesRef.select((state) => state.length));
    return ListView.builder(
      shrinkWrap: true,
      itemBuilder: _buildNote,
      itemCount: notesCount,
    );
  }

  Widget _buildRecordButton() {
    return Container(
      child: Text(
        "hold to record",
        style: TextStyle(color: Colors.white),
      ),
      padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 50.0),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100.0),
          color: Color.fromRGBO(169, 129, 234, 0.9)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BinderScope(
        overrides: [
          notesLogicRef
              .overrideWith((scope) => NotesLogic(scope, widget.outlineId))
        ],
        child: LogicLoader(
            refs: [notesLogicRef],
            builder: (context, loading, child) {
              if (loading) {
                // TODO: black screen
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              return child!;
            },
            child: Scaffold(
              appBar: AppBar(
                  title: Text(context.watch(currentOutlineRef
                      .select((state) => state != null ? state.name : "")))),
              body: _buildBody(),
              floatingActionButton: _buildRecordButton(),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
            )));
  }
}
