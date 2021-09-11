class Note {
  final String id;
  final String filePath;
  final DateTime dateCreated;
  int index;
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
      this.transcript,
      this.duration,
      required this.index});

  Note.fromMap(Map<String, dynamic> map)
      : id = map["id"],
        filePath = map["file_path"],
        dateCreated = DateTime.fromMillisecondsSinceEpoch(map["date_created"],
            isUtc: true),
        outlineId = map["outline_id"],
        transcript = map["transcript"],
        parentNoteId = map["parent_note_id"],
        index = map["order_index"] {
    if (map["duration"] != null) {
      duration = Duration(milliseconds: map["duration"]);
    }
  }

  Map<String, dynamic> get map {
    return {
      "id": id,
      "filePath": filePath,
      "date_created": dateCreated.toUtc().millisecondsSinceEpoch,
      "outline_id": outlineId,
      "transcript": transcript,
      "parent_note_id": parentNoteId,
      "order_index": index,
      "duration": duration != null ? duration!.inMilliseconds : null
    };
  }
}
