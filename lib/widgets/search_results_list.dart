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
              setState(() {
                playing = true;
              });
              context.read<PlayerModel>().playNote(widget.note, () {
                setState(() {
                  playing = false;
                });
              });
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
// push to stack dont clear it

class SearchResultsList extends StatelessWidget {
  final List<GroupedResult> searchResults;
  // instead do search results
  const SearchResultsList({Key? key, required this.searchResults})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    //FutureProvider thing - await result of query and show spinner
    if (searchResults.isEmpty) {
      return const Center(child: Text("no results"));
    }
    return ListView(
      children: searchResults
          .map((e) => ResultGroup(groupedResult: e))
          .toList(growable: false),
      shrinkWrap: true,
    );
  }
}
