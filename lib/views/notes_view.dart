import 'package:binder/binder.dart';
import 'package:flutter/material.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/state/notes_state.dart';

class NotesView extends StatefulWidget {
  const NotesView({Key? key}) : super(key: key);

  @override
  _NotesViewState createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  @override
  Widget build(BuildContext context) {
    // final outlineName =
    //     context.watch(currentOutlineRef.select((outline) => outline!.name));
    return BinderScope(
        overrides: [
          notesLogicRef.overrideWith((scope) => NotesLogic(
              scope,
              Outline(
                  name: "Overridden",
                  id: "none",
                  dateCreated: DateTime.now(),
                  dateUpdated: DateTime.now())))
        ],
        child: LogicLoader(
            refs: [notesLogicRef],
            child: Scaffold(
              appBar: AppBar(title: const Text("Outline")),
            )));
  }
}
