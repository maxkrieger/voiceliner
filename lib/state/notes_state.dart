import 'package:binder/binder.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/repositories/db_repository.dart';

final notesRef = StateRef(const <Note>[]);
final currentOutlineRef = StateRef<Outline?>(null);
final notesLogicRef = LogicRef((scope) => NotesLogic(scope, ""));

class NotesLogic with Logic implements Loadable {
  @override
  final Scope scope;

  final String _outlineId;

  DBRepository get _dbRepository => use(dbRepositoryRef);

  @override
  Future<void> load() async {
    final outlineDict = await _dbRepository.getOutlineFromId(_outlineId);
    final outline = Outline.fromMap(outlineDict);
    write(currentOutlineRef, outline);
    final notesDicts = await _dbRepository.getNotesForOutline(outline);
    final notes = notesDicts
        .map((n) => Note.fromMap(n))
        .toList()
        .sort((a, b) => a.index.compareTo(b.index));
    write(notesRef, notes);
  }

  NotesLogic(this.scope, this._outlineId);
}
