import 'package:binder/binder.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/player_state.dart';

final notesRef = StateRef(const <Note>[]);
final currentOutlineRef = StateRef<Outline?>(null);
final notesLogicRef = LogicRef((scope) => NotesLogic(scope, ""));
final currentlyPlayingOrRecordingRef = StateRef<Note?>(null);

class NotesLogic with Logic implements Loadable {
  @override
  final Scope scope;

  final String _outlineId;

  DBRepository get _dbRepository => use(dbRepositoryRef);
  PlayerLogic get _playerLogic => use(playerLogicRef);

  Future<void> startRecording() async {
    final noteId = uuid.v4();
    final path = read(internalPlayerRef).recordingsDirectory.path;
    final note = Note(
        id: uuid.v4(),
        filePath: "$path/$noteId.aac",
        dateCreated: DateTime.now(),
        outlineId: read(currentOutlineRef)!.id,
        index: read(notesRef).length);
    await _playerLogic.startRecording(note);
    await _dbRepository.addNote(note);
    write(currentlyPlayingOrRecordingRef, note);
    write(notesRef, read(notesRef).toList()..add(note));
  }

  Future<void> stopRecording() async {
    final note = read(currentlyPlayingOrRecordingRef)!;
    note.duration = await _playerLogic.stopRecording(note);
    _dbRepository.updateNote(note);
    // TODO: transcribe
    write(currentlyPlayingOrRecordingRef, null);
  }

  Future<void> playNote(Note note) async {
    write(currentlyPlayingOrRecordingRef, note);
    await _playerLogic.playNote(note);
    write(currentlyPlayingOrRecordingRef, null);
  }

  @override
  Future<void> load() async {
    final outlineDict = await _dbRepository.getOutlineFromId(_outlineId);
    final outline = Outline.fromMap(outlineDict);
    write(currentOutlineRef, outline);
    final notesDicts = await _dbRepository.getNotesForOutline(outline);
    final notes = notesDicts.map((n) => Note.fromMap(n)).toList();
    notes.sort((a, b) => a.index.compareTo(b.index));
    write(notesRef, notes);
  }

  NotesLogic(this.scope, this._outlineId);
}
