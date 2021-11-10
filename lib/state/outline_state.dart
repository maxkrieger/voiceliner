import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/player_state.dart';

final defaultOutline = Outline(
    name: "", id: "", dateCreated: DateTime.now(), dateUpdated: DateTime.now());

class OutlinesModel extends ChangeNotifier {
  OutlinesModel();

  final List<Outline> outlines = [];

  late DBRepository _dbRepository;
  late PlayerModel _playerModel;
  bool isReady = false;

  Future<Outline> createOutline(String name) async {
    final outline = Outline(
        name: name,
        id: uuid.v4(),
        dateCreated: DateTime.now().toUtc(),
        dateUpdated: DateTime.now().toUtc());
    outlines.insert(0, outline);
    notifyListeners();
    await _dbRepository.addOutline(outline);
    return outline;
  }

  Future<void> deleteOutline(Outline outline) async {
    final notes = await _dbRepository.getNotesForOutlineId(outline.id);
    for (final n in notes) {
      final path = _playerModel.getPathFromFilename(n["file_path"]);
      final exists = await File(path).exists();
      if (exists) {
        await File(path).delete();
      }
    }
    await _dbRepository.deleteOutline(outline);
    outlines.removeWhere((element) => element.id == outline.id);
    notifyListeners();
  }

  Future<void> renameOutline(Outline outline, String renameTo) async {
    outline.name = renameTo;
    notifyListeners();
    await _dbRepository.renameOutline(outline);
  }

  Outline getOutlineFromId(String outlineId) =>
      outlines.firstWhere((element) => element.id == outlineId);

  Future<void> load(PlayerModel playerModel, DBRepository db) async {
    if (db.ready && !isReady) {
      Sentry.addBreadcrumb(
          Breadcrumb(message: "Load outlines", timestamp: DateTime.now()));
      _dbRepository = db;
      _playerModel = playerModel;
      final outlineResults = await _dbRepository.getOutlines();
      outlines.clear();
      outlines.addAll(outlineResults
          .map((Map<String, dynamic> res) => Outline.fromMap(res)));
      outlines.sort((a, b) => b.dateUpdated.compareTo(a.dateUpdated));
      isReady = true;
      notifyListeners();
    }
  }
}
