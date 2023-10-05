import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago_flutter/timeago_flutter.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/state/outline_state.dart';
import 'package:voice_outliner/state/player_state.dart';
import 'package:voice_outliner/widgets/note_wizard.dart';

import '../consts.dart';
import 'outlines_list.dart';

class NoteItem extends StatefulWidget {
  final int num;
  final bool showCompleted;
  const NoteItem({Key? key, required this.num, required this.showCompleted})
      : super(key: key);

  @override
  _NoteItemState createState() => _NoteItemState();
}

Color computeColor(int? magnitude) {
  Color a = basePurple;
  Color b = warmRed;
  double t = magnitude != null && magnitude <= 100 ? magnitude / 100 : 0;
  return Color.lerp(a, b, t)!;
}

class _NoteItemState extends State<NoteItem> {
  final _renameController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    _renameController.dispose();
  }

  void _editNoteDetails() {
    final note = context.read<NotesModel>().notes.elementAt(widget.num);

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => NoteWizard(
              initialTranscript: note.transcript ?? "",
              initialColor: note.color ?? 0,
              onSubmit: (transcript, color) async {
                if (note.transcript != transcript) {
                  await context
                      .read<NotesModel>()
                      .setNoteTranscript(note, transcript);
                }
                if (note.color != color) {
                  await context.read<NotesModel>().setNoteColor(note, color);
                }
              },
            ));
  }

  Future<void> _deleteNote() async {
    final note = context.read<NotesModel>().notes.elementAt(widget.num);

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Delete note?"),
              content: Text(
                  "\"${note.transcript ?? note.infoString}\" \n It cannot be restored"),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      "cancel",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                    )),
                TextButton(
                    onPressed: () {
                      final note = context
                          .read<NotesModel>()
                          .notes
                          .elementAt(widget.num);
                      context.read<NotesModel>().deleteNote(note);
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      "delete",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                    ))
              ],
            ));
  }

  List<PopupMenuEntry<String>> _menuBuilder(BuildContext context) {
    final note = context.read<NotesModel>().notes.elementAt(widget.num);
    final allowRetranscription =
        context.read<OutlinesModel>().allowRetranscription;
    final isTranscribing =
        context.read<NotesModel?>()?.isNoteTranscribing(note) ?? false;
    return [
      const PopupMenuItem(
          value: "share",
          child: ListTile(leading: Icon(Icons.share), title: Text("share"))),
      const PopupMenuItem(
          value: "edit",
          child: ListTile(leading: Icon(Icons.edit), title: Text("edit"))),
      const PopupMenuItem(
          value: "move",
          child: ListTile(
              leading: Icon(Icons.playlist_play), title: Text("move"))),
      if (note.latitude != null && note.longitude != null)
        const PopupMenuItem(
            value: "locate",
            child: ListTile(
                leading: Icon(Icons.location_pin), title: Text("location"))),
      if (allowRetranscription && note.filePath != null)
        const PopupMenuItem(
            value: "transcribe",
            child: ListTile(
                leading: Icon(Icons.replay), title: Text("re-transcribe"))),
      const PopupMenuItem(
          value: "delete",
          child: ListTile(leading: Icon(Icons.delete), title: Text("delete"))),
      if (isTranscribing)
        const PopupMenuItem(
            child: ListTile(
                enabled: false,
                title: Text(
                  "waiting to transcribe...",
                  style: TextStyle(fontSize: 15),
                ))),
    ];
  }

  void _shareNote() {
    final note = context.read<NotesModel>().notes.elementAt(widget.num);
    String desc = note.transcript ?? note.infoString;
    if (note.filePath != null) {
      String path =
          context.read<PlayerModel>().getPathFromFilename(note.filePath!);
      Share.shareFiles([path],
          mimeTypes: ["audio/aac"], text: desc, subject: desc);
    } else {
      Share.share(desc);
    }
  }

  Future<void> _moveNote() async {
    final note = context.read<NotesModel>().notes.elementAt(widget.num);
    Navigator.push(context, MaterialPageRoute(builder: (ct) {
      return Scaffold(
          appBar: AppBar(
            title: const Text("Select Outline"),
          ),
          body: OutlinesList(
              excludeItem: note.outlineId,
              onTap: (String outlineId) {
                final note =
                    context.read<NotesModel>().notes.elementAt(widget.num);
                context.read<NotesModel>().moveNote(note, outlineId);
                Navigator.pop(ct);
              }));
    }));
  }

  void _handleMenu(String item) {
    if (item == "delete") {
      _deleteNote();
    } else if (item == "edit") {
      _editNoteDetails();
    } else if (item == "share") {
      _shareNote();
    } else if (item == "move") {
      _moveNote();
    } else if (item == "locate") {
      final note = context.read<NotesModel>().notes.elementAt(widget.num);
      MapsLauncher.launchCoordinates(
          note.latitude!, note.longitude!, note.transcript ?? note.infoString);
    } else if (item == "transcribe") {
      final note = context.read<NotesModel>().notes.elementAt(widget.num);
      context.read<NotesModel>().retranscribeNote(note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = context.select<NotesModel?, Note?>((m) => m == null
        ? null
        : m.notes.length > widget.num
            ? m.notes.elementAt(widget.num)
            : defaultNote);

    if (note == null) {
      return Card(
          child: Center(
              child: Text("drag to reorder",
                  style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).hintColor))),
          clipBehavior: Clip.hardEdge,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          color: const Color.fromRGBO(237, 226, 255, 0.8),
          margin: const EdgeInsets.only(top: 10.0, left: 10.0, right: 10.0));
    }

    // HACK: forces rendering
    final dateCreated = context.select<NotesModel?, DateTime?>((m) {
      return m == null
          ? null
          : m.notes.length > widget.num
              ? m.notes.elementAt(widget.num).dateCreated
              : defaultNote.dateCreated;
    });

    if (note.isComplete && !widget.showCompleted) {
      return const SizedBox(height: 0);
    }
    final isTranscribing =
        context.read<NotesModel?>()?.isNoteTranscribing(note) ?? false;
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
      return notesModel.getDepth(note);
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
            elevation: 0,
            clipBehavior: Clip.hardEdge,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0)),
            color: note.isComplete
                ? const Color.fromRGBO(229, 229, 229, 0.3)
                : computeColor(note.color).withOpacity(0.2),
            margin: EdgeInsets.only(
                top: 6.0, left: 10.0 + 30.0 * min(depth, 5), right: 10.0),
            child: ExpansionTile(
              initiallyExpanded: currentlyExpanded,
              onExpansionChanged: (bool st) {
                context
                    .read<NotesModel>()
                    .setCurrentlyExpanded(st ? note : null);
              },
              tilePadding: const EdgeInsets.only(left: 10),
              trailing: const SizedBox(width: 0, height: 0),
              title: isTranscribing
                  ? Text(
                      "waiting to transcribe...",
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).hintColor),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        note.transcript ?? note.infoString,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            decoration: note.isComplete
                                ? TextDecoration.lineThrough
                                : null),
                      )),
              leading: note.filePath != null
                  ? IconButton(
                      tooltip: "play note",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: classicPurple,
                      onPressed: () =>
                          context.read<NotesModel>().playNote(note),
                      icon: isCurrent
                          ? const Icon(Icons.stop_circle_outlined)
                          : const Icon(Icons.play_circle))
                  : IconButton(
                      onPressed: _editNoteDetails,
                      tooltip: "edit note",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: classicPurple,
                      icon: const Icon(Icons.text_fields)),
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Tooltip(
                      message: "mark note complete",
                      child: Checkbox(
                          activeColor: Colors.deepPurple,
                          value: note.isComplete,
                          onChanged: (v) {
                            context
                                .read<NotesModel>()
                                .setNoteComplete(note, v ?? false);
                            HapticFeedback.mediumImpact();
                          })),
                  const SizedBox(width: 10),
                  Text(
                      note.duration != null
                          ? "${note.duration!.inSeconds}s"
                          : "",
                      style: TextStyle(color: Theme.of(context).hintColor)),
                  const Spacer(),
                  TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Created on: ${dateCreated != null ? DateFormat("${DateFormat.WEEKDAY}, ${DateFormat.MONTH} ${DateFormat.DAY} ${DateFormat.YEAR}").add_jms().format(dateCreated.toLocal()) : "no date"}",
                            ),
                          ),
                        );
                      },
                      child: Timeago(
                          builder: (_, t) => Text(
                                t,
                                style: TextStyle(
                                    color: Theme.of(context).hintColor),
                              ),
                          date: dateCreated!)),
                  PopupMenuButton(
                      tooltip: "note options",
                      itemBuilder: _menuBuilder,
                      icon: const Icon(Icons.more_vert),
                      onSelected: _handleMenu)
                ])
              ],
            )));
  }
}
