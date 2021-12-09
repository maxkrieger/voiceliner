import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voice_outliner/consts.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/outline_state.dart';
import 'package:voice_outliner/views/map_view.dart';
import 'package:voice_outliner/views/notes_view.dart';
import 'package:voice_outliner/views/settings_view.dart';
import 'package:voice_outliner/widgets/outlines_list.dart';
import 'package:voice_outliner/widgets/search_results_list.dart';

class OutlinesView extends StatefulWidget {
  const OutlinesView({Key? key}) : super(key: key);

  @override
  _OutlinesViewState createState() => _OutlinesViewState();
}

class _OutlinesViewState extends State<OutlinesView> {
  bool searchFocused = false;
  List<GroupedResult> searchResults = [];
  final _textController = TextEditingController();
  Future<void> _addOutline() async {
    Future<void> _onSubmitted(BuildContext ctx) async {
      if (_textController.value.text.isNotEmpty) {
        final outline = await ctx
            .read<OutlinesModel>()
            .createOutline(_textController.value.text);
        Navigator.of(ctx, rootNavigator: true).pop();
        _pushOutline(outline.id);
      }
    }

    final now = DateTime.now();
    _textController.text = "${now.month}/${now.day}/${now.year - 2000}";
    _textController.selection = TextSelection(
        baseOffset: 0, extentOffset: _textController.value.text.length);
    await showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
                title: const Text("New Outline"),
                content: TextField(
                    decoration:
                        const InputDecoration(hintText: "Outline Title"),
                    controller: _textController,
                    autofocus: true,
                    autocorrect: false,
                    onSubmitted: (_) => _onSubmitted(dialogCtx),
                    textCapitalization: TextCapitalization.words),
                actions: [
                  TextButton(
                      child: const Text("cancel"),
                      onPressed: () {
                        Navigator.of(dialogCtx, rootNavigator: true).pop();
                      }),
                  TextButton(
                      child: const Text("create"),
                      onPressed: () => _onSubmitted(dialogCtx))
                ]));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _pushOutline(String outlineId) {
    Navigator.pushNamedAndRemoveUntil(context, "/notes", (_) => false,
        arguments: NotesViewArgs(outlineId));
  }

  void _openSettings() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SettingsView()));
  }

  List<PopupMenuEntry<String>> _menuBuilder(BuildContext context) {
    return [
      const PopupMenuItem(
          value: "map",
          child: ListTile(leading: Icon(Icons.map), title: Text("map"))),
      PopupMenuItem(
          value: "show_archived",
          child: context.read<OutlinesModel>().showArchived
              ? const ListTile(
                  leading: Icon(Icons.archive), title: Text("hide archived"))
              : const ListTile(
                  leading: Icon(Icons.unarchive),
                  title: Text("show archived"))),
      const PopupMenuItem(
          value: "settings",
          child:
              ListTile(leading: Icon(Icons.settings), title: Text("settings"))),
    ];
  }

  void _handleMenu(String item) {
    if (item == "settings") {
      _openSettings();
    } else if (item == "map") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const MapView()));
    } else if (item == "show_archived") {
      context.read<OutlinesModel>().toggleShowArchived();
    }
  }

  Future<void> performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }
    final dbModel = context.read<DBRepository>();
    final outlinesModel = context.read<OutlinesModel>();
    // HACK: leaky I know
    final showCompleted = outlinesModel.prefs.getBool(showCompletedKey) ?? true;
    final notesResults =
        await dbModel.searchNotes(query, requireUncomplete: !showCompleted);
    final outlinesResults = await dbModel.searchOutlines(query,
        requireUnarchived: !outlinesModel.showArchived);
    Map<String, GroupedResult> results = {};
    for (var outlineRes in outlinesResults) {
      results[outlineRes["id"]] = GroupedResult(
          outlinesModel.outlines
              .firstWhere((element) => element.id == outlineRes["id"]),
          []);
    }
    for (var noteRes in notesResults) {
      if (!results.containsKey(noteRes["outline_id"])) {
        results[noteRes["outline_id"]] = GroupedResult(
            outlinesModel.outlines
                .firstWhere((element) => element.id == noteRes["outline_id"]),
            []);
      }
      results[noteRes["outline_id"]]?.notes.add(Note.fromMap(noteRes));
    }
    setState(() {
      searchResults = results.values
          .where((element) =>
              outlinesModel.showArchived || !element.outline.archived)
          .toList();
    });
  }

  @override
  Widget build(BuildContext ct) {
    final ready = context.select<OutlinesModel, bool>((value) => value.isReady);
    final numOutlines =
        context.select<OutlinesModel, int>((value) => value.outlines.length);
    final showArchived =
        context.select<OutlinesModel, bool>((value) => value.showArchived);
    if (!ready) {
      return const Scaffold(
          body: Center(
        child: CircularProgressIndicator(),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: searchFocused
            ? IconButton(
                tooltip: "exit search",
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  searchFocused = false;
                }),
              )
            : null,
        title: AnimatedSwitcher(
            child: searchFocused
                ? TextField(
                    showCursor: true,
                    onChanged: performSearch,
                    controller: _textController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "search outlines and notes",
                      suffixIcon: IconButton(
                          onPressed: _textController.clear,
                          icon: const Icon(Icons.clear)),
                    ),
                    autocorrect: false,
                  )
                : const Text("Outlines"),
            duration: const Duration(milliseconds: 300)),
        actions: !(searchFocused)
            ? [
                IconButton(
                  tooltip: "search outlines & notes",
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() {
                    searchFocused = true;
                  }),
                ),
                PopupMenuButton(
                    tooltip: "settings & more",
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: _menuBuilder,
                    onSelected: (String item) => _handleMenu(item))
              ]
            : [],
      ),
      floatingActionButton: !searchFocused
          ? FloatingActionButton(
              tooltip: "Add Outline",
              onPressed: _addOutline,
              child: const Icon(Icons.post_add_rounded),
            )
          : null,
      body: AnimatedCrossFade(
          crossFadeState: searchFocused
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          secondChild: SearchResultsList(searchResults: searchResults),
          firstChild: numOutlines == 0
              ? Center(
                  child: ElevatedButton(
                      onPressed: _addOutline,
                      child: const Text(
                        "create your first outline",
                        style: TextStyle(fontSize: 20.0),
                      )))
              : OutlinesList(
                  onTap: _pushOutline,
                  showArchived: showArchived,
                )),
    );
  }
}
