import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/state/player_state.dart';

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
  bool isReady = false;
  bool toFile = false;
  bool exportAudio = false;
  bool linkAudio = false;
  bool includeCheckboxes = false;
  bool includeDate = false;
  late PlayerModel _playerModel;

  Future<void> _export() async {
    final tempDir = await getTemporaryDirectory();
    var contents = "# ${widget.outline.name} \n";
    final notesModel = widget.notesModel;
    final List<String> filePaths = [];
    final List<String> mimeTypes = [];
    for (var n in notesModel.notes) {
      var line = "- ";
      if (includeCheckboxes) {
        line += (n.isComplete ? "[x] " : "[ ] ");
      }

      if (linkAudio) {
        line +=
            "[${n.transcript ?? n.infoString}](./${n.id}.${Platform.isIOS ? 'aac' : 'wav'})";
      } else {
        line += n.transcript ?? n.infoString;
      }
      if (includeDate && n.transcript != null) {
        line +=
            " (${DateFormat.yMd().add_jm().format(n.dateCreated.toLocal())})";
      }
      line += "\n";
      line = line.padLeft(line.length + 4 * notesModel.getDepth(n), " ");
      contents += line;
    }
    if (toFile) {
      final mdFile = File(
          "${tempDir.path}/${Uri.encodeFull(widget.outline.name.replaceAll("/", "-"))}.md");
      await mdFile.writeAsString(contents);

      filePaths.add(mdFile.path);
      mimeTypes.add('text/markdown');

      if (exportAudio) {
        for (var n in notesModel.notes) {
          if (n.filePath != null) {
            final filePath =
                _playerModel.getPathFromFilename(n.filePath as String);

            filePaths.add(filePath);
            mimeTypes.add("audio/aac");
          }
        }
      }

      await Share.shareFiles(
        filePaths,
        mimeTypes: mimeTypes,
      );
    } else {
      Share.share(contents, subject: widget.outline.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    _playerModel = Provider.of<PlayerModel>(context);
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
                      if (toFile == false) {
                        exportAudio = false;
                        linkAudio = false;
                      }
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
                    })),
            Visibility(
                visible: toFile,
                child: (CheckboxListTile(
                    value: exportAudio,
                    title: const Text("include audio files"),
                    onChanged: (v) => setState(() {
                          exportAudio = v ?? false;
                          if (exportAudio == false) {
                            linkAudio = false;
                          }
                        })))),
            Visibility(
                visible: exportAudio,
                child: (CheckboxListTile(
                    value: linkAudio,
                    title: const Text("link audio files in .md"),
                    onChanged: (v) => setState(() {
                          linkAudio = v ?? false;
                          if (linkAudio == true) {
                            exportAudio = true;
                            toFile = true;
                          }
                        }))))
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

  Future<void> load(PlayerModel playerModel) async {
    if (!isReady) {
      _playerModel = playerModel;
      isReady = true;
    }
  }
}

Future<void> exportMarkdown(
    BuildContext context, Outline outline, NotesModel notesModel) async {
  await showDialog(
      context: context,
      builder: (_) =>
          _MarkdownExporter(outline: outline, notesModel: notesModel));
}
