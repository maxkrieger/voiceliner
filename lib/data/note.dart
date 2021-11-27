import 'dart:collection';

import 'package:intl/intl.dart';

class Note extends LinkedListEntry<Note> {
  final String id;
  final String filePath;
  DateTime dateCreated;
  bool isComplete;
  bool isCollapsed;
  bool transcribed = false;
  bool backedUp = false;
  int? color;
  double? latitude;
  double? longitude;
  Duration? duration;
  String? transcript;
  String? parentNoteId;
  String outlineId;
  Note(
      {required this.id,
      required this.filePath,
      required this.dateCreated,
      required this.outlineId,
      this.parentNoteId,
      this.isComplete = false,
      this.color,
      this.transcript,
      this.duration,
      this.latitude,
      this.longitude,
      required this.isCollapsed});

  Note.fromMap(Map<String, dynamic> map)
      : id = map["id"],
        filePath = map["file_path"],
        dateCreated = DateTime.fromMillisecondsSinceEpoch(map["date_created"],
            isUtc: true),
        outlineId = map["outline_id"],
        transcript = map["transcript"],
        latitude = map["latitude"],
        longitude = map["longitude"],
        color = map["color"],
        parentNoteId = map["parent_note_id"],
        isComplete = map["is_complete"] == 1,
        isCollapsed = map["is_collapsed"] == 1,
        backedUp = map["backed_up"] == 1,
        transcribed = map["transcribed"] == 1 {
    if (map["duration"] != null) {
      duration = Duration(milliseconds: map["duration"]);
    }
  }

  String get infoString =>
      "Recording at ${DateFormat.yMd().add_jm().format(dateCreated.toLocal())}";

  String? get predecessorNoteId => previous?.id;

  Map<String, dynamic> get map {
    return {
      "id": id,
      "file_path": filePath,
      "date_created": dateCreated.toUtc().millisecondsSinceEpoch,
      "outline_id": outlineId,
      "transcript": transcript,
      "parent_note_id": parentNoteId,
      "predecessor_note_id": predecessorNoteId,
      "duration": duration != null ? duration!.inMilliseconds : null,
      "is_complete": isComplete ? 1 : 0,
      "is_collapsed": isCollapsed ? 1 : 0,
      "transcribed": transcribed ? 1 : 0,
      "backed_up": backedUp ? 1 : 0,
      "color": color,
      "latitude": latitude,
      "longitude": longitude
    };
  }
}
