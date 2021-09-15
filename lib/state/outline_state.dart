import 'package:binder/binder.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/repositories/db_repository.dart';

final outlinesRef = StateRef(const <Outline>[]);
final outlinesLogicRef = LogicRef((scope) => OutlineLogic(scope));

class OutlineLogic with Logic implements Loadable {
  OutlineLogic(this.scope);
  @override
  final Scope scope;

  DBRepository get _dbRepository => use(dbRepositoryRef);

  Future<Outline> createOutline(String name) async {
    final outline = Outline(
        name: name,
        id: uuid.v4(),
        dateCreated: DateTime.now().toUtc(),
        dateUpdated: DateTime.now().toUtc());
    write(outlinesRef, read(outlinesRef).toList()..add(outline));
    await _dbRepository.addOutline(outline);
    return outline;
  }

  Future<void> deleteOutline(Outline outline) async {
    await _dbRepository.deleteOutline(outline);
    final outlines = read(outlinesRef).toList();
    outlines.removeWhere((element) => element.id == outline.id);
    write(outlinesRef, outlines);
  }

  Future<void> renameOutline(Outline outline, String renameTo) async {
    final renamedOutline = Outline.fromMap(outline.map);
    renamedOutline.name = renameTo;
    final updatedOutlines = read(outlinesRef).toList();
    updatedOutlines[updatedOutlines
        .indexWhere((element) => element.id == outline.id)] = renamedOutline;
    await _dbRepository.renameOutline(renamedOutline);
    write(outlinesRef, updatedOutlines);
  }

  @override
  Future<void> load() async {
    final outlineResults = await _dbRepository.getOutlines();
    final outlines = outlineResults
        .map((Map<String, dynamic> res) => Outline.fromMap(res))
        .toList();
    outlines.sort((a, b) => a.dateUpdated.compareTo(b.dateUpdated));
    write(outlinesRef, outlines);
  }
}
