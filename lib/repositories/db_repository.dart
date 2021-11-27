import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';

const int dbVersion = 5;

const String noteTableDef = '''
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
      latitude REAL,
      longitude REAL,
      backed_up INTEGER NOT_NULL DEFAULT 0,
      transcribed INTEGER NOT_NULL DEFAULT 1,
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
      date_updated INTEGER NOT NULL,
      archived INTEGER NOT NULL DEFAULT 0
)''');
    batch.execute("CREATE TABLE note($noteTableDef)");
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
    final batch = db.batch();
    print("migrating to $newVersion from $oldVersion ${db.path}");
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Migrating to $newVersion from $oldVersion"));
    if (oldVersion < 2) {
      final List<Map<String, dynamic>> oldNotes =
          await db.query("note", columns: ["id", "order_index", "outline_id"]);

      batch.execute("PRAGMA foreign_keys=OFF");
      batch.execute("ALTER TABLE note RENAME TO tmp_note");
      batch.execute("CREATE TABLE note($noteTableDef)");
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
    }
    if (oldVersion == 2) {
      batch.execute(
          "ALTER TABLE note ADD COLUMN backed_up INTEGER NOT NULL DEFAULT 0");
      batch.execute(
          "ALTER TABLE note ADD COLUMN transcribed INTEGER NOT NULL DEFAULT 1");
    }
    if (oldVersion < 4) {
      batch.execute("ALTER TABLE note ADD COLUMN longitude REAL");
      batch.execute("ALTER TABLE note ADD COLUMN latitude REAL");
    }
    if (oldVersion < 5) {
      batch.execute(
          "ALTER TABLE outline ADD COLUMN archived INTEGER NOT NULL DEFAULT 0");
    }
    print("done migrating");
    await batch.commit();
  }

  Future<void> closeDB() async {
    await _database.close();
  }

  Future<void> resetDB() async {
    await _database.close();
    await deleteDatabase(_database.path);
    ready = false;
    await load();
  }

  void writeOutlineUpdated(Batch batch, String outlineId) {
    batch.rawUpdate("UPDATE outline SET date_updated = ? WHERE id = ?",
        [DateTime.now().toUtc().millisecondsSinceEpoch, outlineId]);
  }

  Future<List<Map<String, dynamic>>> getOutlines() async {
    final result = await _database.query("outline");
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllNotes(
      {bool requireUncomplete = false}) async {
    if (requireUncomplete) {
      final result = await _database.rawQuery(
        "SELECT * FROM note WHERE is_complete = 0 AND NOT EXISTS (SELECT 1 FROM outline WHERE id = note.outline_id AND archived = 1)",
      );
      return result;
    }
    final result = await _database.query("note");
    return result;
  }

  Future<List<Map<String, dynamic>>> searchOutlines(String query,
      {bool requireUnarchived = false}) async {
    final result = await _database.query("outline",
        where: "${requireUnarchived ? 'archived = 0 AND ' : ''}name LIKE ?",
        whereArgs: ["%$query%"]);
    return result;
  }

  Future<List<Map<String, dynamic>>> searchNotes(String query,
      {bool requireUncomplete = false}) async {
    final result = await _database.query("note",
        where:
            "${requireUncomplete ? 'is_complete = 0 AND ' : ''}transcript IS NOT NULL AND transcript LIKE ?",
        whereArgs: ["%$query%"]);
    return result;
  }

  Future<List<Map<String, dynamic>>> getNotesForOutlineId(String outlineId,
      {bool requireUncomplete = false}) async {
    if (requireUncomplete) {
      final result = await _database.query("note",
          where: "outline_id = ? AND is_complete = 0", whereArgs: [outlineId]);
      return result;
    }
    final result = await _database
        .query("note", where: "outline_id = ?", whereArgs: [outlineId]);
    return result;
  }

  Future<void> moveNote(Note note, String outlineId) async {
    final nMap = note.map;
    final toNotes = await getNotesForOutlineId(outlineId);
    nMap["predecessor_note_id"] = null;
    final batch = _database.batch();
    batch.update("note", nMap, where: "id = ?", whereArgs: [note.id]);
    if (toNotes.isNotEmpty) {
      final fst = toNotes
          .firstWhere((element) => element["predecessor_note_id"] == null);
      batch.rawUpdate("UPDATE note SET predecessor_note_id = ? WHERE id = ?",
          [note.id, fst["id"]]);
    }
    writeOutlineUpdated(batch, outlineId);
    await batch.commit();
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
    writeOutlineUpdated(batch, note.outlineId);
    await batch.commit();
  }

  Future<void> updateNote(Note note) async {
    final batch = _database.batch();
    writeOutlineUpdated(batch, note.outlineId);
    batch.update("note", note.map, where: "id = ?", whereArgs: [note.id]);
    await batch.commit();
  }

  Future<void> renameOutline(Outline outline) async {
    final batch = _database.batch();
    batch.rawUpdate(
        "UPDATE outline SET name = ? WHERE id = ?", [outline.name, outline.id]);
    writeOutlineUpdated(batch, outline.id);
    await batch.commit();
  }

  Future<void> archiveToggleOutline(Outline outline) async {
    final batch = _database.batch();
    batch.rawUpdate("UPDATE outline SET archived = ? WHERE id = ?",
        [outline.archived ? 1 : 0, outline.id]);
    writeOutlineUpdated(batch, outline.id);
    await batch.commit();
  }

  Future<void> realignNotes(LinkedList<Note> notes) async {
    final batch = _database.batch();
    void update(Note element) {
      batch.rawUpdate(
          "UPDATE note SET predecessor_note_id = ?, parent_note_id = ? WHERE id = ?",
          [element.predecessorNoteId, element.parentNoteId, element.id]);
    }

    if (notes.isNotEmpty) {
      writeOutlineUpdated(batch, notes.first.outlineId);
    }

    notes.forEach(update);
    await batch.commit();
  }

  Future<void> deleteNote(Note note) async {
    final batch = _database.batch();
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
        version: dbVersion,
        onCreate: _onCreate,
        onConfigure: _onConfigure,
        onOpen: _onOpen,
        onUpgrade: _onUpgrade);
    _database = db;
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Load db", timestamp: DateTime.now()));
    print(db.path);
  }
}
