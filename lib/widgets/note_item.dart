import 'dart:math';

import 'package:binder/binder.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago_flutter/timeago_flutter.dart';
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
    final note = context.read(notesRef)[widget.num];
    Future<void> _onSubmitted(BuildContext ctx) async {
      if (_renameController.value.text.isNotEmpty) {
        await context
            .use(notesLogicRef)
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
                      final note = ctx.read(notesRef)[widget.num];
                      ctx.use(notesLogicRef).deleteNote(note);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text("delete"))
              ],
            ));
  }

  List<PopupMenuEntry<String>> _menuBuilder(BuildContext context) {
    return const [
      PopupMenuItem(
          value: "share",
          child: ListTile(leading: Icon(Icons.share), title: Text("share"))),
      PopupMenuItem(
          value: "edit",
          child: ListTile(leading: Icon(Icons.edit), title: Text("edit text"))),
      PopupMenuItem(
          value: "delete",
          child: ListTile(leading: Icon(Icons.delete), title: Text("delete")))
    ];
  }

  void _shareNote() {
    final note = context.read(notesRef)[widget.num];
    String path =
        context.use(playerLogicRef).getPathFromFilename(note.filePath);
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
    final note = context.watch(notesRef.select((state) =>
        widget.num < state.length ? state[widget.num] : defaultNote));
    final isCurrent =
        context.watch(currentlyPlayingOrRecordingRef.select((state) {
      return state != null && note.id == state.id;
    }));
    //TODO: make computed
    final currentlyExpanded = context.watch(currentlyExpandedRef
        .select((state) => state != null && state.id == note.id));
    final depth = context.watch(notesRef.select((notes) {
      int getDepth(String? id) {
        if (id != null) {
          final predecessor = notes.firstWhere((element) => element.id == id,
              orElse: () => defaultNote);
          return 1 + getDepth(predecessor.parentNoteId);
        }
        return 0;
      }

      final d = getDepth(notes[widget.num].parentNoteId);
      return d;
    }));
    return Dismissible(
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.2,
          DismissDirection.endToStart: 0.2,
        },
        movementDuration: const Duration(milliseconds: 100),
        dragStartBehavior: DragStartBehavior.down,
        confirmDismiss: (direction) async {
          if (note.index == 0) {
            return false;
          }
          HapticFeedback.mediumImpact();
          if (direction == DismissDirection.startToEnd) {
            context.use(notesLogicRef).indentNote(note);
          } else if (direction == DismissDirection.endToStart) {
            context.use(notesLogicRef).outdentNote(note);
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
                context.use(notesLogicRef).setExpansion(st ? note : null);
              },
              trailing: const SizedBox(width: 0),
              tilePadding: EdgeInsets.zero,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Checkbox(
                      value: note.isComplete,
                      onChanged: (v) => context
                          .use(notesLogicRef)
                          .setNoteComplete(note, v ?? false)),
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
                        child: Text(
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
                  onPressed: () => context.use(notesLogicRef).playNote(note),
                  icon: isCurrent
                      ? const Icon(Icons.stop_circle_outlined)
                      : const Icon(Icons.play_circle_outlined)),
            )));
  }
}
