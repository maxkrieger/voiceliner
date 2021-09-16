import 'package:binder/binder.dart';
import 'package:flutter/material.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/state/outline_state.dart';
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
  final _renameController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    _renameController.dispose();
    _scrollController.dispose();
  }

  bool _onAddNote<T>(StateRef<T> ref, T oldState, T newState, Object? action) {
    if (ref.key.name == "notes" &&
        oldState is List<Note> &&
        newState is List<Note>) {
      if (oldState.length < newState.length) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn);
      }
    }
    return false;
  }

  List<PopupMenuItem<String>> _menuBuilder(BuildContext context) {
    return [
      const PopupMenuItem(
          value: "rename",
          child: ListTile(
              leading: Icon(Icons.drive_file_rename_outline),
              title: Text("rename outline"))),
      const PopupMenuItem(
          value: "delete",
          child: ListTile(
              leading: Icon(Icons.delete_forever),
              title: Text("delete outline"))),
    ];
  }

  void _handleMenu(String item) {
    final outline = context
        .read(outlinesRef)
        .firstWhere((element) => element.id == widget.outlineId);
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
                        ctx.use(outlinesLogicRef).deleteOutline(outline);
                        await Navigator.pushNamedAndRemoveUntil(
                            ctx, "/", (route) => false);
                      },
                      child: const Text("delete"))
                ],
              ));
    } else if (item == "rename") {
      Future<void> _onSubmitted(BuildContext ctx) async {
        if (_renameController.value.text.isNotEmpty) {
          await context
              .use(outlinesLogicRef)
              .renameOutline(outline, _renameController.value.text);
          Navigator.of(ctx, rootNavigator: true).pop();
        }
      }

      _renameController.text = outline.name;
      _renameController.selection = TextSelection(
          baseOffset: 0, extentOffset: _renameController.value.text.length);
      showDialog(
          barrierDismissible: false,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOutlineName = context.watch(outlinesRef.select((state) => state
        .firstWhere((element) => element.id == widget.outlineId,
            orElse: () => defaultOutline)
        .name));
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
        actions: [
          PopupMenuButton(itemBuilder: _menuBuilder, onSelected: _handleMenu)
        ],
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
