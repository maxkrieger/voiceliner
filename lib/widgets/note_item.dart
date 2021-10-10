import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago_flutter/timeago_flutter.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/state/player_state.dart';

class NoteItem extends StatefulWidget {
  final int num;
  const NoteItem({Key? key, required this.num}) : super(key: key);

  @override
  _NoteItemState createState() => _NoteItemState();
}

class _NoteItemState extends State<NoteItem> {
  final _renameController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    _renameController.dispose();
  }

  void _changeNoteTranscript() {
    final note = context.read<NotesModel>().notes.elementAt(widget.num);
    Future<void> _onSubmitted(BuildContext ctx) async {
      if (_renameController.value.text.isNotEmpty) {
        await context
            .read<NotesModel>()
            .setNoteTranscript(note, _renameController.value.text);
        Navigator.of(ctx, rootNavigator: true).pop();
      }
    }

    _renameController.text = note.transcript ?? "";
    _renameController.selection = TextSelection(
        baseOffset: 0, extentOffset: _renameController.value.text.length);
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (dialogCtx) => AlertDialog(
                title: const Text("Change text"),
                content: TextField(
                    maxLines: null,
                    decoration: const InputDecoration(hintText: "Transcript"),
                    controller: _renameController,
                    autofocus: true,
                    autocorrect: false,
                    onSubmitted: (_) => _onSubmitted(dialogCtx),
                    textCapitalization: TextCapitalization.sentences),
                actions: [
                  TextButton(
                      child: const Text("cancel"),
                      onPressed: () {
                        Navigator.of(dialogCtx, rootNavigator: true).pop();
                      }),
                  TextButton(
                      child: const Text("set"),
                      onPressed: () => _onSubmitted(dialogCtx))
                ]));
  }

  Future<void> _deleteNote() async {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Delete note?"),
              content: const Text("It cannot be restored"),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: const Text("cancel")),
                TextButton(
                    onPressed: () {
                      final note = context
                          .read<NotesModel>()
                          .notes
                          .elementAt(widget.num);
                      context.read<NotesModel>().deleteNote(note);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text("delete"))
              ],
            ));
  }

  List<PopupMenuEntry<String>> _menuBuilder(BuildContext context) {
    final note = context.read<NotesModel>().notes.elementAt(widget.num);
    final shouldTranscribe = context.read<NotesModel>().shouldTranscribe;
    return [
      const PopupMenuItem(
          value: "share",
          child: ListTile(leading: Icon(Icons.share), title: Text("share"))),
      const PopupMenuItem(
          value: "edit",
          child: ListTile(leading: Icon(Icons.edit), title: Text("edit text"))),
      const PopupMenuItem(
          value: "delete",
          child: ListTile(leading: Icon(Icons.delete), title: Text("delete"))),
      if (!note.transcribed && shouldTranscribe)
        const PopupMenuItem(
            child: ListTile(
                enabled: false,
                title: Text(
                  "waiting to transcribe...",
                  style: TextStyle(fontSize: 15),
                )))
    ];
  }

  void _shareNote() {
    final note = context.read<NotesModel>().notes.elementAt(widget.num);
    String path =
        context.read<PlayerModel>().getPathFromFilename(note.filePath);
    String desc = note.transcript ??
        "note from ${DateFormat.yMd().add_jm().format(note.dateCreated.toLocal())}";
    Share.shareFiles([path], text: desc, subject: desc);
  }

  void _handleMenu(String item) {
    if (item == "delete") {
      _deleteNote();
    } else if (item == "edit") {
      _changeNoteTranscript();
    } else if (item == "share") {
      _shareNote();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldTranscribe = context.read<NotesModel>().shouldTranscribe;
    final note = context.select<NotesModel?, Note?>((m) => m == null
        ? null
        : m.notes.length > widget.num
            ? m.notes.elementAt(widget.num)
            : defaultNote);
    if (note == null) {
      return Card(
          child: const Center(
              child: Text(
            "drag to reorder",
            style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Color.fromRGBO(0, 0, 0, 0.5)),
          )),
          clipBehavior: Clip.hardEdge,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          color: const Color.fromRGBO(237, 226, 255, 0.8),
          margin: const EdgeInsets.only(top: 10.0, left: 10.0, right: 10.0));
    }
    final isCurrent = context.select<NotesModel?, bool>((value) => value == null
        ? false
        : value.currentlyPlayingOrRecording != null &&
            value.currentlyPlayingOrRecording!.id == note.id);
    //TODO: make computed
    final currentlyExpanded = context.select<NotesModel?, bool>((value) =>
        value == null
            ? false
            : value.currentlyExpanded != null &&
                value.currentlyExpanded!.id == note.id);

    final depth = context.select<NotesModel?, int>((notesModel) {
      if (notesModel == null || widget.num >= notesModel.notes.length) {
        return 0;
      }
      final notes = notesModel.notes;
      int getDepth(String? id) {
        if (id != null) {
          final predecessor = notes.firstWhere((element) => element.id == id,
              orElse: () => defaultNote);
          return 1 + getDepth(predecessor.parentNoteId);
        }
        return 0;
      }

      final d = getDepth(notes.elementAt(widget.num).parentNoteId);
      return d;
    });
    return Dismissible(
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.2,
          DismissDirection.endToStart: 0.2,
        },
        movementDuration: const Duration(milliseconds: 100),
        dragStartBehavior: DragStartBehavior.down,
        confirmDismiss: (direction) async {
          if (note.previous == null) {
            return false;
          }
          HapticFeedback.mediumImpact();
          if (direction == DismissDirection.startToEnd) {
            context.read<NotesModel>().indentNote(note);
          } else if (direction == DismissDirection.endToStart) {
            context.read<NotesModel>().outdentNote(note);
          }
        },
        background: Align(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: const [
              SizedBox(width: 20.0),
              Icon(Icons.arrow_forward)
            ])),
        secondaryBackground: Align(
            child:
                Row(mainAxisAlignment: MainAxisAlignment.end, children: const [
          Icon(Icons.arrow_back),
          SizedBox(width: 20.0),
        ])),
        key: Key("dismissable-${note.id}-$currentlyExpanded"),
        child: Card(
            clipBehavior: Clip.hardEdge,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0)),
            color: note.isComplete
                ? const Color.fromRGBO(229, 229, 229, 1.0)
                : const Color.fromRGBO(237, 226, 255, 0.8),
            margin: EdgeInsets.only(
                top: 10.0, left: 10.0 + 30.0 * min(depth, 5), right: 10.0),
            child: ExpansionTile(
              initiallyExpanded: currentlyExpanded,
              onExpansionChanged: (bool st) {
                context
                    .read<NotesModel>()
                    .setCurrentlyExpanded(st ? note : null);
              },
              trailing: const SizedBox(width: 0),
              tilePadding: EdgeInsets.zero,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Checkbox(
                      value: note.isComplete,
                      onChanged: (v) {
                        context
                            .read<NotesModel>()
                            .setNoteComplete(note, v ?? false);
                        HapticFeedback.mediumImpact();
                      }),
                  const Spacer(),
                  Timeago(
                      builder: (_, t) => Text(
                            t,
                            style: const TextStyle(
                                color: Color.fromRGBO(0, 0, 0, .5)),
                          ),
                      date: note.dateCreated),
                  PopupMenuButton(
                      itemBuilder: _menuBuilder,
                      icon: const Icon(Icons.more_vert),
                      onSelected: _handleMenu)
                  // IconButton(
                  //     tooltip: "collapse children",
                  //     onPressed: () {},
                  //     icon: const Icon(
                  //       Icons.keyboard_arrow_down,
                  //       color: Colors.deepPurple,
                  //     ))
                ])
              ],
              title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                        child: shouldTranscribe && !note.transcribed
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ))
                            : Text(
                                note.transcript == null
                                    ? "Recording at ${DateFormat.yMd().add_jm().format(note.dateCreated.toLocal())}"
                                    : note.transcript!,
                                style: TextStyle(
                                    decoration: note.isComplete
                                        ? TextDecoration.lineThrough
                                        : null),
                              )),
                    Text(
                      note.duration != null
                          ? "${note.duration!.inSeconds}s"
                          : "",
                      style:
                          const TextStyle(color: Color.fromRGBO(0, 0, 0, .5)),
                    )
                  ]),
              leading: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => context.read<NotesModel>().playNote(note),
                  icon: isCurrent
                      ? const Icon(Icons.stop_circle_outlined)
                      : const Icon(Icons.play_circle_outlined)),
            )));
  }
}
