import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/state/player_state.dart';
import 'package:voice_outliner/views/notes_view.dart';
import 'package:voice_outliner/widgets/note_item.dart';

class GroupedResult {
  final List<Note> notes;
  final Outline outline;
  GroupedResult(this.outline, this.notes);
}

class ResultNote extends StatefulWidget {
  final Note note;
  const ResultNote({Key? key, required this.note}) : super(key: key);

  @override
  _ResultNoteState createState() => _ResultNoteState();
}

class _ResultNoteState extends State<ResultNote> {
  bool playing = false;
  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: IconButton(
            tooltip: "play note",
            padding: EdgeInsets.zero,
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
            constraints: const BoxConstraints(),
            icon: playing
                ? const Icon(Icons.stop_circle_outlined)
                : const Icon(Icons.play_circle_outlined)),
        onTap: () => Navigator.pushNamed(context, "/notes",
            arguments: NotesViewArgs(widget.note.outlineId,
                scrollToNoteId: widget.note.id)),
        title: Text(widget.note.transcript ?? "Untitled"));
  }
}

class ResultGroup extends StatelessWidget {
  final GroupedResult groupedResult;
  const ResultGroup({Key? key, required this.groupedResult}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: ListTile(
          onTap: () => Navigator.pushNamed(context, "/notes",
              arguments: NotesViewArgs(groupedResult.outline.id)),
          title: Text(groupedResult.outline.name),
          subtitle: Column(
              children: groupedResult.notes
                  .map((e) => Card(
                      clipBehavior: Clip.hardEdge,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0)),
                      color: computeColor(e.color),
                      margin: const EdgeInsets.all(5.0),
                      child: ResultNote(
                        note: e,
                      )))
                  .toList(growable: false))),
    );
  }
}

class SearchResultsList extends StatelessWidget {
  final List<GroupedResult> searchResults;
  // instead do search results
  const SearchResultsList({Key? key, required this.searchResults})
      : super(key: key);

  void _removeFocus(BuildContext context) {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    //FutureProvider thing - await result of query and show spinner
    if (searchResults.isEmpty) {
      return const Center(
          child: Text(
        "no results",
        style: TextStyle(fontSize: 24, color: Color.fromRGBO(0, 0, 0, 0.5)),
      ));
    }
    // HACK to hide keyboard https://stackoverflow.com/questions/51652897/how-to-hide-soft-input-keyboard-on-flutter-after-clicking-outside-textfield-anyw
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _removeFocus(context),
        onTapDown: (_) => _removeFocus(context),
        child: Column(children: [
          Expanded(
              child: Scrollbar(
                  child: ListView(
            shrinkWrap: true,
            children: searchResults
                .map((e) => ResultGroup(groupedResult: e))
                .toList(growable: false),
          )))
        ]));
  }
}
