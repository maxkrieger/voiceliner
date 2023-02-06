import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/consts.dart';
import 'package:voice_outliner/data/outline.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/repositories/drive_backup.dart';
import 'package:voice_outliner/state/player_state.dart';

final defaultOutline = Outline(
    name: "",
    emoji: "📓",
    id: "",
    dateCreated: DateTime.now(),
    dateUpdated: DateTime.now(),
    archived: false);

class OutlinesModel extends ChangeNotifier {
  OutlinesModel();

  final List<Outline> outlines = [];

  late DBRepository _dbRepository;
  late PlayerModel _playerModel;
  late SharedPreferences prefs;
  bool isReady = false;
  bool showArchived = false;
  bool showCompleted = true;
  // Not sure where else to put this state
  bool allowRetranscription = false;

  Future<Outline> createOutline(String name, String emoji) async {
    final now = DateTime.now();
    final outline = Outline(
        name: name,
        emoji: emoji,
        id: uuid.v4(),
        dateCreated: now.toUtc(),
        dateUpdated: now.toUtc(),
        archived: false);
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

  Future<void> renameOutline(Outline outline, String name, String emoji) async {
    outline.name = name;
    outline.emoji = emoji;
    notifyListeners();
    await _dbRepository.renameOutline(outline);
  }

  Future<void> toggleArchive(Outline outline) async {
    outline.archived = !outline.archived;
    notifyListeners();
    await _dbRepository.archiveToggleOutline(outline);
  }

  Outline getOutlineFromId(String outlineId) =>
      outlines.firstWhere((element) => element.id == outlineId);

  Future<void> loadOutlines() async {
    final outlineResults = await _dbRepository.getOutlines();
    outlines.clear();
    outlines.addAll(
        outlineResults.map((Map<String, dynamic> res) => Outline.fromMap(res)));
    outlines.sort((a, b) => b.dateUpdated.compareTo(a.dateUpdated));
    isReady = true;
    notifyListeners();
  }

  void toggleShowArchived() {
    showArchived = !showArchived;
    prefs.setBool(showArchivedKey, showArchived);
    notifyListeners();
  }

  void setShowCompleted(bool show) {
    showCompleted = show;
    prefs.setBool(showCompletedKey, showCompleted);
    notifyListeners();
  }

  void setAllowRetranscription(bool allow) {
    allowRetranscription = allow;
    prefs.setBool(allowRetranscriptionKey, allowRetranscription);
    notifyListeners();
  }

  Future<void> load(PlayerModel playerModel, DBRepository db) async {
    if (db.ready && !isReady) {
      Sentry.addBreadcrumb(
          Breadcrumb(message: "Load outlines", timestamp: DateTime.now()));
      _dbRepository = db;
      _playerModel = playerModel;
      prefs = await SharedPreferences.getInstance();
      showArchived = prefs.getBool(showArchivedKey) ?? false;
      showCompleted = prefs.getBool(showCompletedKey) ?? true;
      allowRetranscription = prefs.getBool(allowRetranscriptionKey) ?? false;
      await loadOutlines();
      await tryBackup();
    }
  }
}
