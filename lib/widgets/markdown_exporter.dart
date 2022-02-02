import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/state/notes_state.dart';

class _MarkdownExporter extends StatefulWidget {
  final Outline outline;
  final NotesModel notesModel;
  const _MarkdownExporter(
      {Key? key, required this.outline, required this.notesModel})
      : super(key: key);

  @override
  _MarkdownExporterState createState() => _MarkdownExporterState();
}

class _MarkdownExporterState extends State<_MarkdownExporter> {
  bool toFile = false;
  bool includeCheckboxes = false;
  bool includeDate = false;
  Future<void> _export() async {
    var contents = "# ${widget.outline.name} \n";
    final notesModel = widget.notesModel;
    for (var n in notesModel.notes) {
      var line = "- ";
      if (includeCheckboxes) {
        line += (n.isComplete ? "[x] " : "[ ] ");
      }
      line += n.transcript ?? n.infoString;
      if (includeDate && n.transcript != null) {
        line +=
            " (${DateFormat.yMd().add_jm().format(n.dateCreated.toLocal())})";
      }
      line += "\n";
      line = line.padLeft(line.length + 4 * notesModel.getDepth(n), " ");
      contents += line;
    }
    if (toFile) {
      final tempDir = await getTemporaryDirectory();
      final file = File(
          "${tempDir.path}/${Uri.encodeFull(widget.outline.name.replaceAll("/", "-"))}.md");
      await file.writeAsString(contents);
      await Share.shareFiles([file.path],
          mimeTypes: ["text/markdown"], text: "${widget.outline.name}.md");
    } else {
      Share.share(contents, subject: widget.outline.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text("Export ${widget.outline.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
                value: toFile,
                title: const Text("as .md file"),
                onChanged: (v) => setState(() {
                      toFile = v ?? false;
                    })),
            CheckboxListTile(
                value: includeCheckboxes,
                title: const Text("with checkboxes"),
                onChanged: (v) => setState(() {
                      includeCheckboxes = v ?? false;
                    })),
            CheckboxListTile(
                value: includeDate,
                title: const Text("with datestamps"),
                onChanged: (v) => setState(() {
                      includeDate = v ?? false;
                    }))
          ],
        ),
        actions: [
          TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
              },
              child: Text(
                "cancel",
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              )),
          TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _export();
              },
              child: Text(
                "export",
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ))
        ]);
  }
}

Future<void> exportMarkdown(
    BuildContext context, Outline outline, NotesModel notesModel) async {
  await showDialog(
      context: context,
      builder: (_) =>
          _MarkdownExporter(outline: outline, notesModel: notesModel));
}
