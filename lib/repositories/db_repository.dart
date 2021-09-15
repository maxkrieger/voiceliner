import 'package:binder/binder.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/state/player_state.dart';

final dbRepositoryRef = LogicRef((scope) => DBRepository(scope));
final dbReadyRef = StateRef(false);
final dbRef = StateRef<Database?>(null);

final Uuid uuid = Uuid();

class DBRepository with Logic implements Loadable, Disposable {
  DBRepository(this.scope);

  Database? get _database => read(dbRef);

  @override
  Future<void> dispose() async {
    await _database?.close();
  }

  Future<void> _onCreate(Database db, int version) async {
    final Batch batch = db.batch();
    batch.execute('''
CREATE TABLE outline (
      id TEXT PRIMARY KEY NOT NULL, 
      name TEXT NOT NULL,
      date_created INTEGER NOT NULL,
      date_updated INTEGER NOT NULL
)''');
    batch.execute('''
CREATE TABLE note (
      id TEXT PRIMARY KEY NOT NULL, 
      file_path TEXT NOT NULL,
      date_created INTEGER NOT NULL,
      is_complete INTEGER NOT NULL,
      duration INTEGER,
      transcript TEXT,
      parent_note_id TEXT,
      outline_id TEXT NOT NULL,
      order_index INTEGER NOT NULL,
      FOREIGN KEY(parent_note_id) REFERENCES note,
      FOREIGN KEY(outline_id) REFERENCES outline
)''');
    await batch.commit(noResult: true);
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute("PRAGMA foreign_keys=ON");
  }

  Future<void> _onOpen(Database db) async {
    write(dbReadyRef, true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    throw ("Need to upgrade db version $oldVersion to $newVersion");
  }

  Future<void> resetDB() async {
    await deleteDatabase(_database!.path);
    await read(internalPlayerRef).recordingsDirectory.delete(recursive: true);
    await load();
  }

  Future<List<Map<String, dynamic>>> getOutlines() async {
    final result = await _database!.query("outline");
    return result;
  }

  Future<List<Map<String, dynamic>>> getNotesForOutline(Outline outline) async {
    final result = await _database!
        .query("note", where: "outline_id = ?", whereArgs: [outline.id]);
    return result;
  }

  Future<Map<String, dynamic>> getOutlineFromId(String outlineId) async {
    final result = await _database!
        .query("outline", where: "id = ?", whereArgs: [outlineId]);
    return result.first;
  }

  Future<void> addOutline(Outline outline) async {
    await _database!.insert("outline", outline.map);
  }

  Future<void> addNote(Note note) async {
    final batch = _database!.batch();
    batch.insert("note", note.map);
    batch.rawUpdate("UPDATE outline SET date_updated = ? WHERE id = ?",
        [DateTime.now().toUtc().millisecondsSinceEpoch, note.outlineId]);
    await batch.commit();
  }

  Future<void> updateNote(Note note) async {
    final batch = _database!.batch();
    batch.rawUpdate("UPDATE outline SET date_updated = ? WHERE id = ?",
        [DateTime.now().toUtc().millisecondsSinceEpoch, note.outlineId]);
    batch.update("note", note.map, where: "id = ?", whereArgs: [note.id]);
    await batch.commit();
  }

  @override
  Future<void> load() async {
    final db = await openDatabase("voice_outliner.db",
        version: 1,
        onCreate: _onCreate,
        onConfigure: _onConfigure,
        onOpen: _onOpen,
        onUpgrade: _onUpgrade);
    write(dbRef, db);
  }

  @override
  final Scope scope;
}
