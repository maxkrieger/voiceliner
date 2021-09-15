import 'package:binder/binder.dart';
import 'package:flutter/material.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/widgets/note_item.dart';
import 'package:voice_outliner/widgets/record_button.dart';

class NotesViewArgs {
  final String outlineId;
  NotesViewArgs(this.outlineId);
}

class NotesViewWrapper extends StatelessWidget {
  const NotesViewWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final outlineId =
        (ModalRoute.of(context)!.settings.arguments as NotesViewArgs).outlineId;
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
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

  bool _onAddNote<T>(StateRef<T> ref, T oldState, T newState, Object? action) {
    print("ok");
    if (ref.key.name == "notes" &&
        oldState is List<Note> &&
        newState is List<Note>) {
      if (oldState.length < newState.length) {
        print("yes");
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currentOutlineName = context.watch(
        currentOutlineRef.select((state) => state != null ? state.name : ""));
    final noteCount = context.watch(notesRef.select((state) => state.length));
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(currentOutlineName),
        leading: IconButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, "/", (_) => false);
            },
            icon: const Icon(Icons.view_list_rounded)),
      ),
      body: BinderScope(
          observers: [DelegatingStateObserver(_onAddNote)],
          child: noteCount > 0
              ? ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 150),
                  shrinkWrap: true,
                  itemBuilder: (_, int idx) =>
                      NoteItem(key: Key("note-$idx"), num: idx),
                  itemCount: noteCount,
                )
              : const Center(
                  child: Text(
                  "no notes yet!",
                  style: TextStyle(
                      fontSize: 40.0, color: Color.fromRGBO(0, 0, 0, 0.5)),
                ))),
      floatingActionButton: const RecordButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
