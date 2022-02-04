import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/views/map_view.dart';
import 'package:voice_outliner/widgets/result_note.dart';

class TimelineView extends StatefulWidget {
  const TimelineView({Key? key}) : super(key: key);

  @override
  _TimelineViewState createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  int? numNotes;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _init);
  }

  Future<void> _init() async {
    final count = await context.read<DBRepository>().getNotesCount();
    setState(() {
      numNotes = count;
    });
  }

  Future<Note?> _retrieveNote(int index) async {
    return await context.read<DBRepository>().getNoteAt(index);
  }

  Widget _renderItem(BuildContext ctx, Note note) {
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                padding: const EdgeInsets.only(bottom: 5, left: 10),
                child: Text(
                  DateFormat.yMd().add_jm().format(note.dateCreated.toLocal()),
                  style:
                      TextStyle(fontSize: 14, color: Theme.of(ctx).hintColor),
                )),
            ResultNote(
              note: note,
              truncate: true,
            )
          ],
        ));
  }

  Widget _buildItem(BuildContext context, int index) {
    return FutureBuilder(
      key: Key("i-$index"),
      builder: (ctx, snapshot) {
        if (snapshot.hasData && snapshot.data is Note) {
          final data = snapshot.data as Note;
          return _renderItem(ctx, data);
        } else {
          return _renderItem(ctx, defaultNote);
        }
      },
      future: _retrieveNote(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Timeline"),
          actions: [
            IconButton(
              tooltip: "map",
              icon: const Icon(Icons.map),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const MapView())),
            ),
          ],
        ),
        body: numNotes == null
            ? Center(
                child: Text(
                "loading...",
                style:
                    TextStyle(fontSize: 24, color: Theme.of(context).hintColor),
              ))
            : numNotes == 0
                ? Center(
                    child: Text(
                    "no notes yet!",
                    style: TextStyle(
                        fontSize: 24, color: Theme.of(context).hintColor),
                  ))
                : Scrollbar(
                    child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 50, top: 20),
                        reverse: true,
                        shrinkWrap: true,
                        prototypeItem: _renderItem(context, defaultNote),
                        itemCount: numNotes,
                        itemBuilder: _buildItem)));
  }
}
