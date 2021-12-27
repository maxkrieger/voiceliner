import 'package:flutter/material.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/widgets/note_item.dart';

class NoteWizard extends StatefulWidget {
  final Note note;
  final Function(String transcript, int color) onSubmit;
  const NoteWizard({Key? key, required this.note, required this.onSubmit})
      : super(key: key);

  @override
  _NoteWizardState createState() => _NoteWizardState();
}

class _NoteWizardState extends State<NoteWizard> {
  final TextEditingController _textController = TextEditingController();
  double color = 0;
  Future<void> _onSubmitted() async {
    if (_textController.value.text.isNotEmpty) {
      widget.onSubmit(_textController.value.text, color.toInt());
      Navigator.of(context, rootNavigator: true).pop();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Note is empty")));
    }
  }

  @override
  void initState() {
    super.initState();
    color = widget.note.color?.toDouble().abs() ?? 0;
    _textController.text = widget.note.transcript ?? "";
    _textController.selection = TextSelection(
        baseOffset: 0, extentOffset: _textController.value.text.length);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text("Edit note"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                maxLines: null,
                decoration: const InputDecoration(hintText: "Transcript"),
                controller: _textController,
                autofocus: true,
                autocorrect: false,
                onSubmitted: (_) => _onSubmitted(),
                textCapitalization: TextCapitalization.sentences),
            const SizedBox(height: 15),
            Slider(
                label: "temperature",
                semanticFormatterCallback: (c) => "temperature $c/100",
                min: 0,
                max: 100,
                divisions: 100,
                activeColor: computeColor(color.toInt()),
                value: color,
                onChanged: (v) {
                  setState(() {
                    color = v;
                  });
                })
          ],
        ),
        actions: [
          TextButton(
              child: Text(
                "cancel",
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              }),
          TextButton(
              child: Text(
                "save",
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              onPressed: () => _onSubmitted())
        ]);
  }
}
