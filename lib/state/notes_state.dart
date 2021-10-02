import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/player_state.dart';

final defaultNote = Note(
    id: "",
    filePath: "",
    dateCreated: DateTime.now(),
    outlineId: "",
    isCollapsed: false);

class NotesModel extends ChangeNotifier {
  bool shouldTranscribe = false;
  bool isReady = false;
  bool isIniting = false;
  final LinkedList<Note> notes = LinkedList<Note>();
  final scrollController = ScrollController();
  Note? currentlyExpanded;
  Note? _currentlyPlayingOrRecording;
  Note? get currentlyPlayingOrRecording => _currentlyPlayingOrRecording;
  set currentlyPlayingOrRecording(Note? note) {
    _currentlyPlayingOrRecording = note;
    notifyListeners();
  }

  final String _outlineId;
  late PlayerModel _playerModel;
  late DBRepository _dbRepository;

  NotesModel(this._outlineId);

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  Future<void> setCurrentlyExpanded(Note? note) async {
    await Future.delayed(const Duration(milliseconds: 200));
    currentlyExpanded = note;
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (currentlyPlayingOrRecording != null) {
      return;
    }
    final noteId = uuid.v4();
    String? parent;
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
        isCollapsed: false);
    await _playerModel.startRecording(note);
    currentlyPlayingOrRecording = note;
  }

  Future<void> stopRecording() async {
    _playerModel.playerState = PlayerState.processing;
    // prevent cutoff
    await Future.delayed(const Duration(milliseconds: 500));
    final note = currentlyPlayingOrRecording;
    if (note == null) {
      _playerModel.stopRecording();
      currentlyPlayingOrRecording = null;
      return;
    }
    note.duration = await _playerModel.stopRecording(note: note);
    if (shouldTranscribe) {
      final res = await _playerModel.speechRecognizer
          .recognize(note, _playerModel.getPathFromFilename(note.filePath));
      note.transcript = res;
    }
    if (currentlyExpanded != null) {
      note.parentNoteId = currentlyExpanded!.id;
      currentlyExpanded!.insertAfter(note);
    } else {
      notes.add(note);
      if (scrollController.hasClients) {
        scrollController.animateTo(scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn);
      }
    }
    notifyListeners();
    await _dbRepository.addNote(note);
    currentlyPlayingOrRecording = null;
    _playerModel.playerState = PlayerState.ready;
  }

  Future<void> playNote(Note note) async {
    if (currentlyPlayingOrRecording != null) {
      _playerModel.stopPlaying();
      currentlyPlayingOrRecording = null;
      return;
    }
    if (currentlyExpanded != null && currentlyExpanded!.id != note.id) {
      currentlyExpanded = null;
    }
    currentlyPlayingOrRecording = note;
    await _playerModel.playNote(note, () {
      currentlyPlayingOrRecording = null;
    });
  }

  Future<void> indentNote(Note noteToIndent) async {
    if (noteToIndent.previous == null) {
      return;
    }
    String predecessorId;
    final prev = noteToIndent.previous!;
    if (noteToIndent.parentNoteId == null) {
      if (prev.parentNoteId == null) {
        predecessorId = prev.id;
      } else {
        predecessorId = prev.parentNoteId!;
      }
    } else {
      predecessorId = prev.id;
    }
    noteToIndent.parentNoteId = predecessorId;
    notifyListeners();
    await _dbRepository.updateNote(noteToIndent);
  }

  Future<void> outdentNote(Note noteToOutdent) async {
    if (noteToOutdent.previous == null) {
      return;
    }
    // TODO: find siblings below self and give them same parent
    String? getParent(String? n) {
      if (n == null) {
        return null;
      }
      return notes.firstWhere((element) => element.id == n).parentNoteId;
    }

    noteToOutdent.parentNoteId = getParent(noteToOutdent.parentNoteId);
    notifyListeners();
    await _dbRepository.updateNote(noteToOutdent);
  }

  Future<void> deleteNote(Note note) async {
    final path = _playerModel.getPathFromFilename(note.filePath);
    await File(path).delete();
    note.unlink();
    notifyListeners();
    await _dbRepository.deleteNote(note, notes);
  }

  // Snapshot hack
  Future<void> rebuildNote(Note note) async {
    note.insertAfter(Note.fromMap(note.map));
    note.unlink();
    notifyListeners();
    await _dbRepository.updateNote(note);
  }

  Future<void> setNoteTranscript(Note note, String transcript) async {
    note.transcript = transcript;
    await rebuildNote(note);
  }

  Future<void> setNoteComplete(Note note, bool complete) async {
    note.isComplete = complete;
    await rebuildNote(note);
  }

  Future<void> swapNotes(int a, int b) async {
    if (a == b || b - 1 == a) {
      return;
    }
    Sentry.addBreadcrumb(Breadcrumb(message: "Swapping $a to $b"));
    int initialSize = notes.length;
    final noteA = notes.elementAt(a);
    if (b == 0) {
      noteA.unlink();
      notes.addFirst(noteA);
    } else {
      //TODO: handle gooder
      final dest = notes.elementAt(b - 1);
      noteA.unlink();
      dest.insertAfter(noteA);

      if (noteA.parentNoteId != null) {
        noteA.parentNoteId = noteA.previous!.id;
      }
    }
    await _dbRepository.realignNotes(notes);
    assert(notes.length == initialSize);
    notifyListeners();
  }

  Future<void> load(PlayerModel playerModel, DBRepository db) async {
    if (!isReady & !isIniting &&
        db.ready &&
        playerModel.playerState == PlayerState.ready) {
      isIniting = true;
      _playerModel = playerModel;
      _dbRepository = db;
      final outlineDict = await _dbRepository.getOutlineFromId(_outlineId);
      final outline = Outline.fromMap(outlineDict);
      final notesDicts = await _dbRepository.getNotesForOutline(outline);
      if (notesDicts.isNotEmpty) {
        var noteToFindSuccessor = Note.fromMap(notesDicts
            .firstWhere((element) => element["predecessor_note_id"] == null));
        notes.addFirst(noteToFindSuccessor);
        while (notesDicts.any((element) =>
            element["predecessor_note_id"] == noteToFindSuccessor.id)) {
          final n = Note.fromMap(notesDicts.firstWhere((element) =>
              element["predecessor_note_id"] == noteToFindSuccessor.id));
          noteToFindSuccessor.insertAfter(n);
          noteToFindSuccessor = n;
        }
      }
      currentlyExpanded = null;
      currentlyPlayingOrRecording = null;
      final prefs = await SharedPreferences.getInstance();
      shouldTranscribe = prefs.getBool("should_transcribe") ?? false;
      isReady = true;
      notifyListeners();
      isIniting = false;
    }
  }
}
