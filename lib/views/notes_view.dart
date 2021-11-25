import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timeago_flutter/timeago_flutter.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/state/outline_state.dart';
import 'package:voice_outliner/state/player_state.dart';
import 'package:voice_outliner/views/map_view.dart';
import 'package:voice_outliner/widgets/note_item.dart';
import 'package:voice_outliner/widgets/record_button.dart';

import '../consts.dart';

class NotesViewArgs {
  final String outlineId;
  final String? scrollToNoteId;
  NotesViewArgs(this.outlineId, {this.scrollToNoteId});
}

class NotesView extends StatelessWidget {
  const NotesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)!.settings.arguments as NotesViewArgs);
    return ChangeNotifierProxyProvider2<PlayerModel, DBRepository, NotesModel>(
      child: _NotesView(args: args),
      create: (BuildContext context) => NotesModel(args.outlineId),
      update: (_, pl, db, n) => (n ?? NotesModel(args.outlineId))..load(pl, db),
    );
  }
}

class _NotesView extends StatefulWidget {
  final NotesViewArgs args;
  const _NotesView({Key? key, required this.args}) : super(key: key);

  @override
  _NotesViewState createState() => _NotesViewState();
}

class _NotesViewState extends State<_NotesView> {
  final _renameController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    _renameController.dispose();
  }

  @override
  void initState() {
    super.initState();
    tryScroll();
  }

  Future<void> tryScroll() async {
    await context.read<NotesModel>().finishedInit;
    await Future.delayed(const Duration(milliseconds: 200));
    final model = context.read<NotesModel>();
    final scrollController = model.scrollController;
    if (scrollController.hasClients) {
      if (widget.args.scrollToNoteId == null) {
        scrollController.animateTo(scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn);
      } else {
        final idx = model.notes
            .toList(growable: false)
            .indexWhere((element) => element.id == widget.args.scrollToNoteId);
        scrollController.scrollToIndex(idx,
            preferPosition: AutoScrollPosition.middle);
        scrollController.highlight(idx);
        final note = model.notes.elementAt(idx);
        model.setCurrentlyExpanded(note);
      }
    }
  }

  List<PopupMenuEntry<String>> _menuBuilder(BuildContext context) {
    final outlineId = widget.args.outlineId;
    final outline = context.read<OutlinesModel>().getOutlineFromId(outlineId);
    return [
      const PopupMenuItem(
          value: "rename",
          child: ListTile(
              leading: Icon(Icons.drive_file_rename_outline),
              title: Text("rename outline"))),
      if (context.read<NotesModel>().shouldLocate)
        const PopupMenuItem(
            value: "map",
            child: ListTile(leading: Icon(Icons.map), title: Text("view map"))),
      const PopupMenuItem(
          value: "export_md",
          child: ListTile(
              leading: Icon(Icons.receipt_long),
              title: Text("export markdown"))),
      const PopupMenuItem(
          value: "delete",
          child: ListTile(
              leading: Icon(Icons.delete_forever),
              title: Text("delete outline"))),
      const PopupMenuDivider(),
      PopupMenuItem(
          value: "time",
          child: ListTile(
            enabled: false,
            title: Timeago(
                builder: (_, t) => Text(
                      "created $t",
                      style: const TextStyle(fontSize: 15),
                    ),
                date: outline.dateCreated.toLocal()),
          ))
    ];
  }

  void _handleMenu(String item, String outlineId) {
    final outline = context.read<OutlinesModel>().getOutlineFromId(outlineId);
    if (item == "delete") {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text("Delete outline?"),
                content: const Text("It cannot be restored"),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      child: const Text("cancel")),
                  TextButton(
                      onPressed: () async {
                        ctx.read<OutlinesModel>().deleteOutline(outline);
                        await Navigator.pushNamedAndRemoveUntil(
                            ctx, "/", (route) => false);
                      },
                      child: const Text("delete"))
                ],
              ));
    } else if (item == "rename") {
      Future<void> _onSubmitted(BuildContext ctx) async {
        if (_renameController.value.text.isNotEmpty) {
          await ctx
              .read<OutlinesModel>()
              .renameOutline(outline, _renameController.value.text);
          Navigator.of(ctx, rootNavigator: true).pop();
        }
      }

      _renameController.text = outline.name;
      _renameController.selection = TextSelection(
          baseOffset: 0, extentOffset: _renameController.value.text.length);
      showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
                  title: Text("Rename Outline '${outline.name}'"),
                  content: TextField(
                      decoration:
                          const InputDecoration(hintText: "Outline Title"),
                      controller: _renameController,
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
                        child: const Text("rename"),
                        onPressed: () => _onSubmitted(dialogCtx))
                  ]));
    } else if (item == "export_md") {
      context.read<NotesModel>().exportToMarkdown(outline);
    } else if (item == "map") {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MapView(
                    outlineId: outlineId,
                  )));
    } else if (item == "time") {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(outline.dateCreated.toLocal().toString())));
    } else {
      print("unhandled");
      Sentry.captureMessage("Unhandled item", level: SentryLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = context.select<NotesModel, bool>((value) => value.isReady);
    if (!ready) {
      return const Scaffold(
          body: Center(
        child: CircularProgressIndicator(),
      ));
    }
    return buildChild(context);
  }

  Widget buildChild(BuildContext context) {
    final outlineId = widget.args.outlineId;
    final currentOutlineName = context.select<OutlinesModel, String>((value) =>
        value.outlines
            .firstWhere((element) => element.id == outlineId,
                orElse: () => defaultOutline)
            .name);
    final noteCount =
        context.select<NotesModel, int>((value) => value.notes.length);
    final scrollController = context.select<NotesModel, AutoScrollController>(
        (value) => value.scrollController);
    final playerState =
        context.select<PlayerModel, PlayerState>((value) => value.playerState);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TextButton(
          style: TextButton.styleFrom(
              primary: Colors.white, textStyle: const TextStyle(fontSize: 20)),
          child: Text(
            currentOutlineName,
          ),
          onPressed: () => _handleMenu("rename", outlineId),
        ),
        leading: IconButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, "/", (_) => false);
            },
            icon: const Icon(Icons.view_list_rounded)),
        actions: [
          PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: _menuBuilder,
              onSelected: (String item) => _handleMenu(item, outlineId))
        ],
      ),
      body: (playerState == PlayerState.notReady
          ? const Center(child: Text("setting up..."))
          : playerState == PlayerState.error
              ? const Center(child: Text("error"))
              : playerState == PlayerState.noPermission
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                          const Text("to start recording notes,",
                              style: TextStyle(fontSize: 20.0)),
                          ElevatedButton(
                              onPressed: () {
                                context.read<PlayerModel>().tryPermission();
                              },
                              child: const Text("grant microphone access"))
                        ]))
                  : (noteCount == 0)
                      ? Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: const [
                              Text("no notes yet!",
                                  style: TextStyle(
                                      fontSize: 40.0,
                                      color: Color.fromRGBO(0, 0, 0, 0.5))),
                              SizedBox(
                                height: 12.0,
                              ),
                              Text(
                                "swipe notes to indent them",
                                style: TextStyle(
                                    fontSize: 20.0,
                                    color: Color.fromRGBO(0, 0, 0, 0.5)),
                              )
                            ]))
                      : Scrollbar(
                          controller: scrollController,
                          interactive: true,
                          child: ReorderableListView.builder(
                            onReorder: (a, b) {
                              context.read<NotesModel>().swapNotes(a, b);
                              HapticFeedback.mediumImpact();
                            },
                            scrollController: scrollController,
                            padding: const EdgeInsets.only(bottom: 150),
                            shrinkWrap: true,
                            itemBuilder: (_, int idx) => AutoScrollTag(
                                key: ValueKey(idx),
                                controller: scrollController,
                                highlightColor: classicPurple.withOpacity(0.5),
                                index: idx,
                                child:
                                    NoteItem(key: Key("note-$idx"), num: idx)),
                            itemCount: noteCount,
                          ))),
      floatingActionButton: const RecordButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
