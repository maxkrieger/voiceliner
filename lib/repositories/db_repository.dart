import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';

const String tableCreator = '''
      id TEXT PRIMARY KEY NOT NULL, 
      file_path TEXT,
      date_created INTEGER NOT NULL,
      is_complete INTEGER NOT NULL,
      is_collapsed INTEGER NOT NULL DEFAULT 0,
      duration INTEGER,
      transcript TEXT,
      predecessor_note_id TEXT,
      parent_note_id TEXT,
      outline_id TEXT NOT NULL,
      color INTEGER,
      FOREIGN KEY(parent_note_id) REFERENCES note,
      FOREIGN KEY(predecessor_note_id) REFERENCES note,
      FOREIGN KEY(outline_id) REFERENCES outline
''';

const Uuid uuid = Uuid();

class DBRepository extends ChangeNotifier {
  DBRepository();

  late Database _database;
  bool ready = false;

  @override
  Future<void> dispose() async {
    super.dispose();
    await _database.close();
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
    batch.execute("CREATE TABLE note($tableCreator)");
    await batch.commit(noResult: true);
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute("PRAGMA foreign_keys=ON");
  }

  Future<void> _onOpen(Database db) async {
    ready = true;
    notifyListeners();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      print("migrating to 2 ${db.path}");
      Sentry.addBreadcrumb(Breadcrumb(message: "Migrating to v2"));
      final List<Map<String, dynamic>> oldNotes =
          await db.query("note", columns: ["id", "order_index", "outline_id"]);

      final batch = db.batch();
      batch.execute("PRAGMA foreign_keys=OFF");
      batch.execute("ALTER TABLE note RENAME TO tmp_note");
      batch.execute("CREATE TABLE note($tableCreator)");
      batch.execute('''INSERT INTO note(
      id,
      file_path,
      date_created,
      is_complete,
      duration,
      transcript,
      parent_note_id,
      outline_id,
      color
      )
      SELECT id,
      file_path,
      date_created,
      is_complete,
      duration,
      transcript,
      parent_note_id,
      outline_id,
      color
      FROM tmp_note''');
      batch.execute("DROP TABLE tmp_note");
      batch.execute("PRAGMA foreign_keys=ON");
      final Map<String, List<Map<String, dynamic>>> outlines = {};
      for (var n in oldNotes) {
        if (outlines[n["outline_id"]] != null) {
          outlines[n["outline_id"]]?.add(n);
        } else {
          outlines[n["outline_id"]] = [n];
        }
      }
      for (var o in outlines.values) {
        o.sort((a, b) => a["order_index"].compareTo(b["order_index"]));
        for (var i = 0; i < o.length; i++) {
          batch.update("note",
              {"predecessor_note_id": i == 0 ? null : o[i - 1]["id"] as String},
              where: "id = ?", whereArgs: [o[i]["id"]]);
        }
      }
      await batch.commit();
      print("done migrating");
    }
    // if oldVersion < x
  }

  Future<void> resetDB() async {
    await _database.close();
    await deleteDatabase(_database.path);
    ready = false;
    await load();
  }

  Future<List<Map<String, dynamic>>> getOutlines() async {
    final result = await _database.query("outline");
    return result;
  }

  Future<List<Map<String, dynamic>>> getNotesForOutline(Outline outline) async {
    final result = await _database
        .query("note", where: "outline_id = ?", whereArgs: [outline.id]);
    return result;
  }

  Future<Map<String, dynamic>> getOutlineFromId(String outlineId) async {
    final result = await _database
        .query("outline", where: "id = ?", whereArgs: [outlineId]);
    return result.first;
  }

  Future<void> addOutline(Outline outline) async {
    await _database.insert("outline", outline.map);
  }

  Future<void> addNote(Note note) async {
    final batch = _database.batch();
    batch.insert("note", note.map);
    batch.rawUpdate("UPDATE outline SET date_updated = ? WHERE id = ?",
        [DateTime.now().toUtc().millisecondsSinceEpoch, note.outlineId]);
    await batch.commit();
  }

  Future<void> updateNote(Note note) async {
    final batch = _database.batch();
    batch.rawUpdate("UPDATE outline SET date_updated = ? WHERE id = ?",
        [DateTime.now().toUtc().millisecondsSinceEpoch, note.outlineId]);
    batch.update("note", note.map, where: "id = ?", whereArgs: [note.id]);
    await batch.commit();
  }

  Future<void> renameOutline(Outline outline) async {
    await _database.rawUpdate(
        "UPDATE outline SET name = ? WHERE id = ?", [outline.name, outline.id]);
  }

  Future<void> realignNotes(LinkedList<Note> notes) async {
    final batch = _database.batch();
    void update(Note element) {
      batch.rawUpdate(
          "UPDATE note SET predecessor_note_id = ?, parent_note_id = ? WHERE id = ?",
          [element.predecessorNoteId, element.parentNoteId, element.id]);
    }

    notes.forEach(update);
    await batch.commit();
  }

  Future<void> deleteNote(Note note, LinkedList<Note> notes) async {
    final batch = _database.batch();
    void update(Note element) {
      batch.rawUpdate(
          "UPDATE note SET predecessor_note_id = ?, parent_note_id = ? WHERE id = ?",
          [element.predecessorNoteId, element.parentNoteId, element.id]);
    }

    notes.forEach(update);
    batch.delete("note", where: "id = ?", whereArgs: [note.id]);
    await batch.commit();
  }

  Future<void> deleteOutline(Outline outline) async {
    final batch = _database.batch();

    batch.delete("note", where: "outline_id = ?", whereArgs: [outline.id]);
    batch.delete("outline", where: "id = ?", whereArgs: [outline.id]);
    await batch.commit();
  }

  Future<void> load() async {
    final db = await openDatabase("voice_outliner.db",
        version: 2,
        onCreate: _onCreate,
        onConfigure: _onConfigure,
        onOpen: _onOpen,
        onUpgrade: _onUpgrade);
    _database = db;
  }
}
