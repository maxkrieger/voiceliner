import 'package:binder/binder.dart';
import 'package:flutter/material.dart';
import 'package:voice_outliner/state/outline_state.dart';
import 'package:voice_outliner/views/notes_view.dart';
import 'package:voice_outliner/views/settings_view.dart';

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
        final outline = await context
            .use(outlinesLogicRef)
            .createOutline(_textController.value.text);
        Navigator.of(ctx, rootNavigator: true).pop();
        _pushOutline(ctx, outline.id);
      }
    }

    final now = DateTime.now();
    _textController.text = "${now.month}/${now.day}/${now.year}";
    _textController.selection = TextSelection(
        baseOffset: 0, extentOffset: _textController.value.text.length);
    await showDialog(
        barrierDismissible: false,
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

  void _pushOutline(BuildContext ctx, String outlineId) {
    Navigator.pushNamedAndRemoveUntil(ctx, "/notes", (_) => false,
        arguments: NotesViewArgs(outlineId));
  }

  Widget _buildOutline(BuildContext ctx, int num) {
    final outline = ctx.watch(outlinesRef.select(
        (outlines) => num < outlines.length ? outlines[num] : defaultOutline));
    return Card(
        key: Key("outline-$num"),
        child: ListTile(
          title: Text(outline.name),
          onLongPress: () {
            print("long press");
          },
          onTap: () {
            _pushOutline(ctx, outline.id);
          },
        ));
  }

  void _openSettings() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SettingsView()));
  }

  @override
  Widget build(BuildContext ct) {
    return LogicLoader(
        refs: [outlinesLogicRef],
        builder: (context, loading, child) {
          if (loading) {
            return const CircularProgressIndicator();
          }
          final numOutlines =
              context.watch(outlinesRef.select((outlines) => outlines.length));
          return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: const Text("Voice Outliner"),
                actions: [
                  IconButton(
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings))
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
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: numOutlines,
                      itemBuilder: _buildOutline));
        });
  }
}
