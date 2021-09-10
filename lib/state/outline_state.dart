import 'package:binder/binder.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/repositories/db_repository.dart';

class CurrentOutline {
  final Outline outline;
  final List<Note> notes;
  CurrentOutline(this.outline, this.notes);
}

final outlinesRef = StateRef(const <Outline>[]);
final currentOutlineRef = StateRef<CurrentOutline?>(null);

class OutlineLogic with Logic implements Loadable {
  OutlineLogic(this.scope);
  @override
  final Scope scope;

  DBRepository get _dbRepository => use(dbRepositoryRef);

  @override
  Future<void> load() async {
    final outlineResults = await _dbRepository.getOutlines();
    final outlines =
        outlineResults.map((Map<String, dynamic> res) => Outline.fromMap(res));
    write(outlinesRef, outlines);
    if (outlines.isNotEmpty) {
      //  TODO: read current from storage
      final outline = outlines.first;
      final noteResults = await _dbRepository.getNotesForOutline(outline);
      final notes =
          noteResults.map((res) => Note.fromMap(res)).toList(growable: false);
      write(currentOutlineRef, CurrentOutline(outline, notes));
    }
  }
}
