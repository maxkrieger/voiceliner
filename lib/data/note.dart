class Note {
  final String id;
  final String filePath;
  final DateTime dateCreated;
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
      this.duration});

  Note.fromMap(Map<String, dynamic> map)
      : id = map["id"],
        filePath = map["file_path"],
        dateCreated = DateTime.fromMillisecondsSinceEpoch(map["date_created"],
            isUtc: true),
        outlineId = map["outline_id"],
        transcript = map["transcript"],
        parentNoteId = map["parent_note_id"] {
    if (map["duration"] != null) {
      duration = Duration(milliseconds: map["duration"]);
    }
  }
}
