import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';
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
    isReady = false;
    scrollController.dispose();
  }

  Future<void> exportToMarkdown(Outline outline) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
        "${tempDir.path}/${Uri.encodeFull(outline.name.replaceAll("/", "-"))}.md");
    var contents = "# ${outline.name} \n";
    for (var n in notes) {
      var line = n.isComplete ? "- [x] " : "- [ ] ";
      line += n.transcript ?? n.infoString;
      line += "\n";
      line = line.padLeft(line.length + 4 * getDepth(n), " ");
      contents += line;
    }
    await file.writeAsString(contents);
    await Share.shareFiles([file.path],
        mimeTypes: ["text/markdown"], text: outline.name);
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Exported note", timestamp: DateTime.now()));
  }

  Future<void> setCurrentlyExpanded(Note? note) async {
    Sentry.addBreadcrumb(Breadcrumb(
        message: "Setting currently expanded", timestamp: DateTime.now()));
    await Future.delayed(const Duration(milliseconds: 200));
    currentlyExpanded = note;
    notifyListeners();
  }

  Future<void> runJobs() async {
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Running jobs", timestamp: DateTime.now()));
    notes.forEach((entry) async {
      if (shouldTranscribe && !entry.transcribed) {
        final res = await _playerModel.speechRecognizer
            .recognize(entry, _playerModel.getPathFromFilename(entry.filePath));
        if (res.item1 && isReady) {
          entry.transcribed = true;
          entry.transcript = res.item2;
          rebuildNote(entry);
        }
      }
    });
  }

  Future<void> startRecording() async {
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Start recording", timestamp: DateTime.now()));
    if (currentlyPlayingOrRecording != null) {
      Sentry.captureMessage(
          "Attempted to start recording when already in progress",
          level: SentryLevel.error);
      return;
    }
    final noteId = uuid.v4();
    String? parent;
    if (notes.isNotEmpty &&
        DateTime.now().difference(notes.last.dateCreated).inMinutes < 2) {
      parent = notes.last.parentNoteId;
    }
    final note = Note(
        id: noteId,
        filePath: "$noteId.aac",
        dateCreated: DateTime.now().toUtc(),
        outlineId: _outlineId,
        parentNoteId: parent,
        isCollapsed: false);
    await _playerModel.startRecording(note);
    currentlyPlayingOrRecording = note;
  }

  Future<void> stopRecording(int color) async {
    // prevent cutoff
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Stop recording", timestamp: DateTime.now()));
    await Future.delayed(const Duration(milliseconds: 300));
    final note = currentlyPlayingOrRecording;
    currentlyPlayingOrRecording = null;
    _playerModel.playerState = PlayerState.ready;
    notifyListeners();
    if (note == null) {
      Sentry.captureMessage("Attempted to stop recording on an empty note",
          level: SentryLevel.error);
      _playerModel.stopRecording();
      return;
    }
    note.color = color;
    note.duration = await _playerModel.stopRecording(note: note);
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Saved file", timestamp: DateTime.now()));

    if (currentlyExpanded != null) {
      note.parentNoteId = currentlyExpanded!.id;
      currentlyExpanded!.insertAfter(note);
      Sentry.addBreadcrumb(Breadcrumb(
          message: "Insert after expanded", timestamp: DateTime.now()));
    } else {
      notes.add(note);
      if (scrollController.hasClients) {
        scrollController.animateTo(scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn);
      }
      Sentry.addBreadcrumb(
          Breadcrumb(message: "Insert bottom", timestamp: DateTime.now()));
    }
    notifyListeners();
    await _dbRepository.addNote(note);
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Added note to db", timestamp: DateTime.now()));
    // NOTE: always realign when inserting
    await _dbRepository.realignNotes(notes);
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Realigned notes", timestamp: DateTime.now()));
    runJobs();
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

  Future<void> moveNote(Note note, String outlineId) async {
    if (currentlyExpanded != null && currentlyExpanded!.id == note.id) {
      currentlyExpanded = null;
    }
    if (currentlyPlayingOrRecording != null &&
        currentlyPlayingOrRecording!.id == note.id) {
      currentlyPlayingOrRecording = null;
    }
    notes.forEach((entry) {
      if (entry.parentNoteId == note.id) {
        entry.parentNoteId = note.parentNoteId;
      }
    });
    note.unlink();
    note.parentNoteId = null;
    note.outlineId = outlineId;
    await _dbRepository.moveNote(note, outlineId);
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
    final path = _playerModel.getPathFromFilename(note.filePath);
    bool exists = await File(path).exists();
    if (exists) {
      await File(path).delete();
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

  // Snapshot hack
  Future<void> rebuildNote(Note note) async {
    final newNote = Note.fromMap(note.map);
    note.insertAfter(newNote);
    note.unlink();
    if (currentlyExpanded != null && currentlyExpanded!.id == note.id) {
      currentlyExpanded = newNote;
    }
    notifyListeners();
    await _dbRepository.updateNote(newNote);
    Sentry.addBreadcrumb(
        Breadcrumb(message: "Rebuilt note", timestamp: DateTime.now()));
  }

  Future<void> setNoteTranscript(Note note, String transcript) async {
    note.transcript = transcript;
    note.transcribed = true;
    await rebuildNote(note);
  }

  Future<void> setNoteComplete(Note note, bool complete) async {
    note.isComplete = complete;
    await rebuildNote(note);
  }

  bool isDescendantOf(Note candidate, Note of) {
    if (candidate.parentNoteId == null) {
      return false;
    }
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
      final prefs = await SharedPreferences.getInstance();
      shouldTranscribe = prefs.getBool("should_transcribe") ?? false;
      isReady = true;
      notifyListeners();
      isIniting = false;
      await runJobs();
    }
  }
}
