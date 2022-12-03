import 'package:flutter/material.dart';
import 'package:voice_outliner/widgets/note_item.dart';

class NoteWizard extends StatefulWidget {
  final String initialTranscript;
  final int initialColor;
  final Function(String transcript, int color) onSubmit;
  final String title;
  const NoteWizard(
      {Key? key,
      required this.initialColor,
      required this.initialTranscript,
      required this.onSubmit,
      this.title = "Edit Note"})
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
    color = widget.initialColor.toDouble().abs();
    _textController.text = widget.initialTranscript;
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
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                maxLines: 10,
                minLines: 1,
                decoration: const InputDecoration(hintText: "Transcript"),
                controller: _textController,
                autofocus: true,
                autocorrect: true,
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
