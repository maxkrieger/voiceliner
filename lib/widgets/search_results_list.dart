import 'package:flutter/material.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/views/notes_view.dart';
import 'package:voice_outliner/widgets/result_note.dart';

class GroupedResult {
  final List<Note> notes;
  final Outline outline;
  GroupedResult(this.outline, this.notes);
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
                  .map((e) => ResultNote(note: e))
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
      return Center(
          child: Text(
        "no results",
        style: TextStyle(fontSize: 24, color: Theme.of(context).hintColor),
      ));
    }
    // HACK to hide keyboard https://stackoverflow.com/questions/51652897/how-to-hide-soft-input-keyboard-on-flutter-after-clicking-outside-textfield-anyw
    // TODO: make scrollbar work with this
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _removeFocus(context),
        onTapDown: (_) => _removeFocus(context),
        child: ListView(
          shrinkWrap: true,
          children: searchResults
              .map((e) => ResultGroup(groupedResult: e))
              .toList(growable: false),
        ));
  }
}
