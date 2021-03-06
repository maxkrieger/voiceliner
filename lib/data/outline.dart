class Outline {
  Outline(
      {required this.name,
      required this.id,
      required this.dateCreated,
      required this.dateUpdated,
      required this.archived,
      required this.emoji});
  String name;
  String emoji;
  final String id;
  bool archived;
  final DateTime dateCreated;
  final DateTime dateUpdated;

  Outline.fromMap(Map<String, dynamic> map)
      : id = map["id"],
        name = map["name"],
        emoji = map["emoji"],
        archived = map["archived"] == 1,
        dateCreated = DateTime.fromMillisecondsSinceEpoch(map["date_created"],
            isUtc: true),
        dateUpdated = DateTime.fromMillisecondsSinceEpoch(map["date_updated"],
            isUtc: true);

  Map<String, dynamic> get map {
    return {
      "id": id,
      "name": name,
      "emoji": emoji,
      "date_created": dateCreated.toUtc().millisecondsSinceEpoch,
      "date_updated": dateCreated.toUtc().millisecondsSinceEpoch,
      "archived": archived ? 1 : 0,
    };
  }
}
