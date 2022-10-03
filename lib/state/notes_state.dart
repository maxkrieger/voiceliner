import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/repositories/ios_speech_recognizer.dart';
import 'package:voice_outliner/repositories/vosk_speech_recognizer.dart';
import 'package:voice_outliner/state/player_state.dart';

import '../consts.dart';

final defaultNote = Note(
    id: "",
    filePath: "",
    dateCreated: DateTime.now(),
    outlineId: "",
    transcript: "Loading...",
    isCollapsed: false);

class NotesModel extends ChangeNotifier {
  bool shouldTranscribe = false;
  bool shouldLocate = false;
  bool showCompleted = true;
  bool isReady = false;
  String locale = "en-US";
  Completer<bool> _readyCompleter = Completer();
  bool isIniting = false;
  final LinkedList<Note> notes = LinkedList<Note>();
  final AutoScrollController scrollController = AutoScrollController();
  Note? currentlyExpanded;
  Note? _currentlyPlayingOrRecording;
  Future<bool> get finishedInit => _readyCompleter.future;
  Note? get currentlyPlayingOrRecording => _currentlyPlayingOrRecording;
  set currentlyPlayingOrRecording(Note? note) {
    _currentlyPlayingOrRecording = note;
    notifyListeners();
  }

  final String _outlineId;
  late PlayerModel _playerModel;
  late DBRepository _dbRepository;
  late SharedPreferences prefs;

  NotesModel(this._outlineId);

  Future<void> toggleShowCompleted() async {
    showCompleted = !showCompleted;
    await prefs.setBool(showCompletedKey, showCompleted);
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
    isReady = false;
    scrollController.dispose();
  }

  Future<void> setCurrentlyExpanded(Note? note) async {
    Sentry.addBreadcrumb(Breadcrumb(
        message: "Setting currently expanded", timestamp: DateTime.now()));
    await Future.delayed(const Duration(milliseconds: 200));
    currentlyExpanded = note;
    notifyListeners();
  }

  bool isNoteTranscribing(Note note) {
    return (shouldTranscribe && !note.transcribed);
  }

  Future<void> transcribe(Note note) async {
    if (shouldTranscribe &&
        (!note.transcribed || note.transcript == null) &&
        note.filePath != null) {
      final path = _playerModel.getPathFromFilename(note.filePath!);
      final res = Platform.isIOS
          ? await recognizeNoteIOS(path, locale)
          : await voskSpeechRecognize(path);
      // Guard against writing after user went back
      if (isReady) {
        note.transcribed = true;
        note.transcript = res;
        await rebuildNote(note);
      }
    }
  }

  Future<void> runJobs() async {
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Running jobs", timestamp: DateTime.now()));
    notes.forEach(transcribe);
  }

  Future<void> createTextNote(String text) async {
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Create text note", timestamp: DateTime.now()));
    final noteId = uuid.v4();
    final note = Note(
        id: noteId,
        dateCreated: DateTime.now().toUtc(),
        outlineId: _outlineId,
        parentNoteId: null,
        filePath: null,
        transcribed: true,
        transcript: text,
        isCollapsed: false);

    if (currentlyExpanded != null && !currentlyExpanded!.isComplete) {
      note.parentNoteId = currentlyExpanded!.id;
      currentlyExpanded!.insertAfter(note);
      await _dbRepository.addNote(note);
      // Due to notes below/nonstandard insertion point
      await _dbRepository.realignNotes(notes);
      Sentry.addBreadcrumb(Breadcrumb(
          message: "Insert after expanded", timestamp: DateTime.now()));
    } else {
      notes.add(note);
      await _dbRepository.addNote(note);
    }
    notifyListeners();
    if (shouldLocate) {
      final loc = await locationInstance.getLocation();
      if (loc.latitude != null &&
          loc.longitude != null &&
          loc.accuracy != null &&
          loc.accuracy! < 1000.0) {
        note.longitude = loc.longitude;
        note.latitude = loc.latitude;
        await _dbRepository.updateNote(note);
      } else {
        Sentry.addBreadcrumb(Breadcrumb(
            message: "Couldn't locate note", timestamp: DateTime.now()));
      }
    }
    notifyListeners();
  }

  Future<void> startRecording() async {
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Start recording", timestamp: DateTime.now()));
    if (currentlyPlayingOrRecording != null) {
      Sentry.captureMessage(
          "Attempted to start recording when already in progress",
          level: SentryLevel.error);
      print("Attempted to start recording when already in progress");
      return;
    }
    final noteId = uuid.v4();
    String? parent;
    if (notes.isNotEmpty &&
        DateTime.now().difference(notes.last.dateCreated).inMinutes < 2 &&
        !notes.last.isComplete) {
      parent = notes.last.parentNoteId;
    }
    final note = Note(
        id: noteId,
        filePath: "$noteId.${Platform.isIOS ? 'aac' : 'wav'}",
        dateCreated: DateTime.now().toUtc(),
        outlineId: _outlineId,
        parentNoteId: parent,
        isCollapsed: false);
    await _playerModel.startRecording(note);
    await _dbRepository.addNote(note);
    Sentry.addBreadcrumb(
        Breadcrumb(message: "added note to db", timestamp: DateTime.now()));
    currentlyPlayingOrRecording = note;
    notifyListeners();
  }

  Future<void> stopRecording(int color) async {
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Stop recording", timestamp: DateTime.now()));

    await _playerModel.stopRecording();
    final note = currentlyPlayingOrRecording;
    currentlyPlayingOrRecording = null;
    notifyListeners();
    if (note == null) {
      Sentry.captureMessage("Attempted to stop recording on an empty note",
          level: SentryLevel.error);
      print("Attempted to stop recording on an empty note");
      return;
    }
    note.color = color;
    note.duration = _playerModel.currentDuration;
    Vibrate.feedback(FeedbackType.medium);
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Saved file", timestamp: DateTime.now()));

    if (currentlyExpanded != null && !currentlyExpanded!.isComplete) {
      note.parentNoteId = currentlyExpanded!.id;
      currentlyExpanded!.insertAfter(note);
      await _dbRepository.updateNote(note);
      // Due to notes below/nonstandard insertion point
      await _dbRepository.realignNotes(notes);
      Sentry.addBreadcrumb(Breadcrumb(
          message: "Insert after expanded", timestamp: DateTime.now()));
    } else {
      notes.add(note);
      await _dbRepository.updateNote(note);
      if (scrollController.hasClients) {
        scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn);
      }
      Sentry.addBreadcrumb(
          Breadcrumb(message: "Insert bottom", timestamp: DateTime.now()));
    }
    notifyListeners();
    if (shouldLocate) {
      final loc = await locationInstance.getLocation();
      if (loc.latitude != null &&
          loc.longitude != null &&
          loc.accuracy != null &&
          loc.accuracy! < 1000.0) {
        note.longitude = loc.longitude;
        note.latitude = loc.latitude;
        await _dbRepository.updateNote(note);
        notifyListeners();
      } else {
        Sentry.addBreadcrumb(Breadcrumb(
            message: "Couldn't locate note", timestamp: DateTime.now()));
      }
    }
    await transcribe(note);
  }

  Future<void> retranscribeNote(Note note) async {
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Retranscribe note", timestamp: DateTime.now()));
    await transcribe(note);
    notifyListeners();
  }

  Future<void> playNote(Note note) async {
    if (currentlyPlayingOrRecording != null) {
      _playerModel.stopPlaying();
      currentlyPlayingOrRecording = null;
      notifyListeners();
      return;
    }
    if (currentlyExpanded != null && currentlyExpanded!.id != note.id) {
      currentlyExpanded = null;
    }
    currentlyPlayingOrRecording = note;
    notifyListeners();
    await _playerModel.playNote(note, () {
      currentlyPlayingOrRecording = null;
      notifyListeners();
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

  int _getDepth(String? id, int depth) {
    if (depth > 8) {
      Sentry.captureMessage("Stack overflow for depth",
          level: SentryLevel.error);
      return 8;
    }
    if (id != null) {
      final predecessor = notes.firstWhere((element) => element.id == id,
          orElse: () => defaultNote);
      return _getDepth(predecessor.parentNoteId, depth + 1);
    }
    return depth;
  }

  int getDepth(Note note) {
    final d = _getDepth(note.parentNoteId, 0);
    return d;
  }

  Future<void> outdentNote(Note noteToOutdent) async {
    if (noteToOutdent.previous == null) {
      return;
    }
    String? getParent(String? n) {
      if (n == null) {
        return null;
      }
      return notes.firstWhere((element) => element.id == n).parentNoteId;
    }

    // Find siblings below self and give them my parent
    bool ready = false;
    for (var i = 0; i < notes.length; i++) {
      if (ready &&
          notes.elementAt(i).parentNoteId == noteToOutdent.parentNoteId) {
        notes.elementAt(i).parentNoteId = getParent(noteToOutdent.parentNoteId);
      }
      if (notes.elementAt(i).id == noteToOutdent.id) {
        ready = true;
      }
    }

    noteToOutdent.parentNoteId = getParent(noteToOutdent.parentNoteId);
    notifyListeners();
    await _dbRepository.updateNote(noteToOutdent);
  }

  bool isDescendantOf(Note candidate, Note of) {
    if (candidate.parentNoteId == null) {
      return false;
    }
    // Is this a useful condition? Identity = true?
    if (candidate.id == of.id) {
      return true;
    }
    if (candidate.parentNoteId == of.id) {
      return true;
    }
    return isDescendantOf(
        notes.firstWhere((element) => element.id == candidate.parentNoteId),
        of);
  }

  Future<void> moveNote(Note note, String outlineId) async {
    if (currentlyExpanded != null && currentlyExpanded!.id == note.id) {
      currentlyExpanded = null;
    }
    if (currentlyPlayingOrRecording != null &&
        currentlyPlayingOrRecording!.id == note.id) {
      currentlyPlayingOrRecording = null;
    }
    final noteAndChildren = LinkedList<Note>();
    final children = notes
        .where(
            (element) => isDescendantOf(element, note) && element.id != note.id)
        .toList(growable: false);
    final newNotes = notes
        .where((element) =>
            !isDescendantOf(element, note) && element.id != note.id)
        .toList(growable: false);
    notes
      ..clear()
      ..addAll(newNotes);
    note.parentNoteId = null;
    noteAndChildren
      ..add(note)
      ..addAll(children);
    await _dbRepository.moveNoteGroup(noteAndChildren, outlineId);
    notifyListeners();
    await _dbRepository.realignNotes(notes);
  }

  Future<void> deleteNote(Note note) async {
    if (currentlyExpanded != null && note.id == currentlyExpanded!.id) {
      currentlyExpanded = null;
    }
    if (currentlyPlayingOrRecording != null &&
        currentlyPlayingOrRecording!.id == note.id) {
      currentlyPlayingOrRecording = null;
    }
    if (note.filePath != null) {
      final path = _playerModel.getPathFromFilename(note.filePath!);
      bool exists = await File(path).exists();
      if (exists) {
        await File(path).delete();
      }
    }
    note.unlink();
    notes.forEach((entry) {
      if (entry.parentNoteId == note.id) {
        entry.parentNoteId = note.parentNoteId;
      }
    });
    notifyListeners();
    await _dbRepository.realignNotes(notes);
    await _dbRepository.deleteNote(note);
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Deleted note", timestamp: DateTime.now()));
  }

  // HACK: forces rendering
  Future<void> rebuildNote(Note note) async {
    note.dateCreated = note.dateCreated.add(const Duration(microseconds: 1));
    notifyListeners();
    await _dbRepository.updateNote(note);
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Rebuilt note", timestamp: DateTime.now()));
  }

  Future<void> setNoteTranscript(Note note, String transcript) async {
    note.transcript = transcript;
    note.transcribed = true;
    await rebuildNote(note);
  }

  Future<void> setNoteColor(Note note, int color) async {
    note.color = color;
    await rebuildNote(note);
  }

  // Buggy function: shouldn't need to set original note separately to get re-render
  Future<void> setNoteComplete(Note note, bool complete) async {
    note.isComplete = complete;
    for (Note entry in notes) {
      if (isDescendantOf(entry, note)) {
        entry.isComplete = complete;
        await rebuildNote(entry);
        if (entry.id == currentlyExpanded?.id) {
          currentlyExpanded = null;
          notifyListeners();
        }
      }
    }
    await rebuildNote(note);
  }

  Future<void> swapNotes(int a, int b) async {
    if (a == b || b - 1 == a) {
      return;
    }
    Sentry.addBreadcrumb(Breadcrumb(message: "Swapping $a to $b"));
    int initialSize = notes.length;
    final noteA = notes.elementAt(a);
    noteA.parentNoteId = null;
    if (b == 0) {
      noteA.unlink();
      notes.addFirst(noteA);
    } else {
      final dest = notes.elementAt(b - 1);
      noteA.unlink();
      final afterDest = dest.next;
      if (afterDest != null && afterDest.parentNoteId != null) {
        noteA.parentNoteId = afterDest.parentNoteId;
      }
      dest.insertAfter(noteA);
    }
    notes.forEach((entry) {
      if (entry.parentNoteId == noteA.id) {
        entry.parentNoteId = null;
      }
    });
    await _dbRepository.realignNotes(notes);
    currentlyExpanded = null;
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Reordered note", timestamp: DateTime.now()));
    assert(notes.length == initialSize);
    notifyListeners();
  }

  Future<void> load(PlayerModel playerModel, DBRepository db) async {
    if (!isReady & !isIniting && db.ready) {
      Sentry.addBreadcrumb(
          Breadcrumb(message: "Running load", timestamp: DateTime.now()));
      isIniting = true;
      _playerModel = playerModel;
      _dbRepository = db;
      final outlineDict = await _dbRepository.getOutlineFromId(_outlineId);
      final outline = Outline.fromMap(outlineDict);
      final notesDicts = await _dbRepository.getNotesForOutlineId(outline.id);
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
      if (notes.length != notesDicts.length) {
        print("Mismatched notes extraction");
        Sentry.captureMessage(
            "Only extracted ${notes.length} from ${notesDicts.length}",
            level: SentryLevel.error);
        notesDicts.forEach((element) {
          if (!notes.any((e) => e.id == element["id"])) {
            notes.add(Note.fromMap(element));
          }
        });
        await _dbRepository.realignNotes(notes);
      }
      currentlyExpanded = null;
      currentlyPlayingOrRecording = null;
      prefs = await SharedPreferences.getInstance();
      shouldTranscribe = prefs.getBool(shouldTranscribeKey) ?? false;
      shouldLocate = prefs.getBool(shouldLocateKey) ?? false;
      showCompleted = prefs.getBool(showCompletedKey) ?? true;
      if (Platform.isIOS) {
        locale = prefs.getString(localeKey) ?? locale;
      }
      isReady = true;
      _readyCompleter.complete(true);
      _readyCompleter = Completer();
      notifyListeners();
      isIniting = false;
      await runJobs();
    }
  }
}
