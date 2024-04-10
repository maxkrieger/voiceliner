import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voice_outliner/consts.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/outline_state.dart';
import 'package:voice_outliner/views/notes_view.dart';
import 'package:voice_outliner/views/settings_view.dart';
import 'package:voice_outliner/views/timeline_view.dart';
import 'package:voice_outliner/widgets/outline_wizard.dart';
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
  Future<void> _addOutline(
      {String? overrideName, String? overrideEmoji}) async {
    final now = DateTime.now();
    final name = overrideName ?? "${now.month}/${now.day}/${now.year - 2000}";
    await launchOutlineWizard(name, overrideEmoji ?? defaultEmoji, context,
        "create", "Create Outline", (name, emoji) async {
      final outline =
          await context.read<OutlinesModel>().createOutline(name, emoji);
      _pushOutline(outline.id);
    }, autofocus: true);
  }

  @override
  void initState() {
    super.initState();
    context.read<OutlinesModel>().loadOutlines();
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
        title: searchFocused
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
            : const Text(
                "Outlines",
              ),
        actions: !(searchFocused)
            ? [
                IconButton(
                  tooltip: "search outlines & notes",
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() {
                    searchFocused = true;
                  }),
                ),
                IconButton(
                  tooltip: "timeline",
                  icon: const Icon(Icons.timeline),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TimelineView())),
                ),
                IconButton(
                  tooltip: "settings",
                  icon: const Icon(Icons.settings),
                  onPressed: _openSettings,
                )
              ]
            : [],
      ),
      floatingActionButton: !searchFocused
          ? FloatingActionButton(
              tooltip: "Add Outline",
              onPressed: _addOutline,
              elevation: 0,
              backgroundColor: classicPurple,
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: const [
                        BoxShadow(
                            offset: Offset(0, 15),
                            blurRadius: 15,
                            spreadRadius: 10,
                            color: Color.fromRGBO(156, 104, 241, 0.5))
                      ]),
                  child: const Icon(Icons.post_add_rounded, color: Colors.white,)),
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
                      onPressed: () => _addOutline(
                          overrideEmoji: "📥", overrideName: "Inbox"),
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
