import 'package:binder/binder.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/repositories/db_repository.dart';

final notesRef = StateRef(const <Note>[]);
final notesLogicRef = LogicRef((scope) => NotesLogic(
    scope,
    Outline(
        name: "dummy",
        id: "none",
        dateCreated: DateTime.now(),
        dateUpdated: DateTime.now())));

class NotesLogic with Logic implements Loadable {
  @override
  final Scope scope;

  final Outline _outline;

  DBRepository get _dbRepository => use(dbRepositoryRef);

  @override
  Future<void> load() async {
    print("load");
    print(_outline.name);
    //  assert currentOutline non null by doing custom binder scope for currentOutline
  }

  NotesLogic(this.scope, this._outline);
}
