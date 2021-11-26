import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voice_outliner/state/outline_state.dart';
import 'package:voice_outliner/views/map_view.dart';
import 'package:voice_outliner/views/notes_view.dart';
import 'package:voice_outliner/views/settings_view.dart';
import 'package:voice_outliner/widgets/outlines_list.dart';

class OutlinesView extends StatefulWidget {
  const OutlinesView({Key? key}) : super(key: key);

  @override
  _OutlinesViewState createState() => _OutlinesViewState();
}

class _OutlinesViewState extends State<OutlinesView> {
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
          title: const Text("Voiceliner"),
          actions: [
            PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: _menuBuilder,
                onSelected: (String item) => _handleMenu(item))
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: "Add Outline",
          onPressed: _addOutline,
          child: const Icon(Icons.post_add_rounded),
        ),
        body: numOutlines == 0
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
              ));
  }
}
