import 'dart:io';

import 'package:binder/binder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/player_state.dart';

final notesRef = StateRef(const <Note>[], name: "notes");
final notesLogicRef = LogicRef((scope) => NotesLogic(scope, ""));
final currentlyPlayingOrRecordingRef = StateRef<Note?>(null);
final currentlyExpandedRef = StateRef<Note?>(null);

final defaultNote = Note(
    id: "", filePath: "", dateCreated: DateTime.now(), outlineId: "", index: 0);

class NotesLogic with Logic implements Loadable {
  @override
  final Scope scope;

  final String _outlineId;

  bool shouldTranscribe = false;

  DBRepository get _dbRepository => use(dbRepositoryRef);
  PlayerLogic get _playerLogic => use(playerLogicRef);

  Future<void> setExpansion(Note? note) async {
    await Future.delayed(const Duration(milliseconds: 200));
    write(currentlyExpandedRef, note);
  }

  Future<void> startRecording() async {
    if (read(currentlyPlayingOrRecordingRef) != null) {
      return;
    }
    final noteId = uuid.v4();
    String? parent;
    final notes = read(notesRef);
    int idx = read(notesRef).length;
    if (notes.isNotEmpty &&
        DateTime.now().difference(notes.last.dateCreated).inMinutes < 2) {
      parent = notes.last.parentNoteId;
    }
    final note = Note(
        id: uuid.v4(),
        filePath: "$noteId.aac",
        dateCreated: DateTime.now().toUtc(),
        outlineId: _outlineId,
        parentNoteId: parent,
        index: idx);
    await _playerLogic.startRecording(note);
    write(currentlyPlayingOrRecordingRef, note);
  }

  Future<void> stopRecording() async {
    write(playerStateRef, PlayerState.processing);
    // prevent cutoff
    await Future.delayed(const Duration(milliseconds: 500));
    final note = read(currentlyPlayingOrRecordingRef);
    if (note == null) {
      _playerLogic.stopRecording();
      write(currentlyPlayingOrRecordingRef, null);
      return;
    }
    note.duration = await _playerLogic.stopRecording(note: note);
    if (shouldTranscribe) {
      final res = await read(speechRecognizerRef)
          .recognize(note, _playerLogic.getPathFromFilename(note.filePath));
      note.transcript = res;
    }
    write(notesRef, read(notesRef).toList()..add(note));
    await _dbRepository.addNote(note);
    write(currentlyPlayingOrRecordingRef, null);
    write(playerStateRef, PlayerState.ready);
  }

  Future<void> playNote(Note note) async {
    if (read(currentlyPlayingOrRecordingRef) != null) {
      _playerLogic.stopPlaying();
      write(currentlyPlayingOrRecordingRef, null);
      return;
    }
    final currentlyExpanded = read(currentlyExpandedRef);
    if (currentlyExpanded != null && currentlyExpanded.id != note.id) {
      write(currentlyExpandedRef, null);
    }
    write(currentlyPlayingOrRecordingRef, note);
    await _playerLogic.playNote(note, () {
      write(currentlyPlayingOrRecordingRef, null);
    });
  }

  Future<void> indentNote(Note noteToIndent) async {
    if (noteToIndent.index == 0) {
      return;
    }
    final notes = read(notesRef).toList();
    final note = Note.fromMap(notes[noteToIndent.index].map);
    String predecessorId;
    final prev = notes[note.index - 1];
    if (note.parentNoteId == null) {
      if (prev.parentNoteId == null) {
        predecessorId = prev.id;
      } else {
        predecessorId = prev.parentNoteId!;
      }
    } else {
      predecessorId = prev.id;
    }
    note.parentNoteId = predecessorId;
    notes[note.index] = note;
    write(notesRef, notes);
    _dbRepository.updateNote(note);
  }

  Future<void> outdentNote(Note noteToOutdent) async {
    if (noteToOutdent.index == 0) {
      return;
    }
    final notes = read(notesRef).toList();
    final note = Note.fromMap(notes[noteToOutdent.index].map);
    // TODO: find siblings below self and give them same parent
    String? getParent(String? n) {
      if (n == null) {
        return null;
      }
      return notes.firstWhere((element) => element.id == n).parentNoteId;
    }

    note.parentNoteId = getParent(note.parentNoteId);
    notes[note.index] = note;
    write(notesRef, notes);
    _dbRepository.updateNote(note);
  }

  Future<void> deleteNote(Note note) async {
    final path = _playerLogic.getPathFromFilename(note.filePath);
    await File(path).delete();
    final notes = read(notesRef).toList();
    notes.removeWhere((element) => note.id == element.id);
    for (var i = 0; i < notes.length; i++) {
      notes[i] = Note.fromMap(notes[i].map);
      notes[i].index = i;
      if (notes[i].parentNoteId == note.id) {
        notes[i].parentNoteId = note.parentNoteId;
      }
    }
    await _dbRepository.deleteNote(note, notes);
    write(notesRef, notes);
  }

  Future<void> setNoteTranscript(Note note, String transcript) async {
    final notes = read(notesRef).toList();
    final newNote = Note.fromMap(note.map);
    newNote.transcript = transcript;
    notes[newNote.index] = newNote;
    await _dbRepository.updateNote(newNote);
    write(notesRef, notes);
  }

  Future<void> setNoteComplete(Note note, bool complete) async {
    final notes = read(notesRef).toList();
    final newNote = Note.fromMap(note.map);
    newNote.isComplete = complete;
    notes[newNote.index] = newNote;
    await _dbRepository.updateNote(newNote);
    write(notesRef, notes);
  }

  @override
  Future<void> load() async {
    final outlineDict = await _dbRepository.getOutlineFromId(_outlineId);
    final outline = Outline.fromMap(outlineDict);
    final notesDicts = await _dbRepository.getNotesForOutline(outline);
    final notes = notesDicts.map((n) => Note.fromMap(n)).toList();
    notes.sort((a, b) => a.index.compareTo(b.index));
    write(notesRef, notes);
    write(currentlyExpandedRef, null);
    write(currentlyPlayingOrRecordingRef, null);
    final prefs = await SharedPreferences.getInstance();
    shouldTranscribe = prefs.getBool("should_transcribe") ?? false;
  }

  NotesLogic(this.scope, this._outlineId);
}
