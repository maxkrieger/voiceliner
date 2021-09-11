import 'package:binder/binder.dart';
import 'package:flutter/material.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/outline_state.dart';

class OutlinesView extends StatefulWidget {
  const OutlinesView({Key? key}) : super(key: key);

  @override
  _OutlinesViewState createState() => _OutlinesViewState();
}

class _OutlinesViewState extends State<OutlinesView> {
  final _textController = TextEditingController();
  Future<void> _addOutline() async {
    void _onSubmitted(BuildContext ctx) {
      if (_textController.value.text.isNotEmpty) {
        final outlineModel = context.use(outlinesLogicRef);
        outlineModel.createOutline(_textController.value.text);
        Navigator.of(ctx, rootNavigator: true).pop();
      }
    }

    final now = DateTime.now();
    _textController.text = "${now.day}/${now.month}/${now.year}";
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

  Widget _buildOutline(BuildContext context, int num) {
    final outline =
        context.watch(outlinesRef.select((outlines) => outlines[num]));
    return Card(child: ListTile(title: Text(outline.name)));
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
              title: const Text("Voice Outliner"),
              actions: [
                IconButton(
                    onPressed: () async {
                      await context.use(dbRepositoryRef).resetDB();
                    },
                    icon: const Icon(Icons.delete))
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
                    itemCount: numOutlines, itemBuilder: _buildOutline),
          );
        });
  }
}
