class Outline {
  Outline({required this.name, required this.id, required this.dateCreated});
  final String name;
  final String id;
  final DateTime dateCreated;

  Outline.fromMap(Map<String, dynamic> map)
      : id = map["id"],
        name = map["name"],
        dateCreated = DateTime.fromMillisecondsSinceEpoch(map["date_created"],
            isUtc: true);

  Map<String, dynamic> get map {
    return {
      "id": id,
      "name": name,
      "date_created": dateCreated.toUtc().millisecondsSinceEpoch
    };
  }
}
