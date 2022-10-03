import 'package:flutter/material.dart';
import 'package:location/location.dart';

const driveEnabledKey = "drive_enabled";
const lastBackupKey = "last_backed_up";
const shouldTranscribeKey = "should_transcribe";
const shouldLocateKey = "should_locate";
const showCompletedKey = "show_completed";
const showArchivedKey = "show_archived";
const allowRetranscriptionKey = "allow_retranscription";
const lastRouteKey = "last_route";
const lastOutlineKey = "last_outline";
const modelDirKey = "model_dir";
const modelLanguageKey = "model_language";
const localeKey = "ios_locale";
const autoDeleteOldBackupsKey = "auto_delete_old_backups";

const classicPurple = Color.fromRGBO(169, 129, 234, 1.0);
const basePurple = Color.fromRGBO(163, 95, 255, 1);
const warmRed = Color.fromRGBO(241, 52, 125, 1.0);
const warningRed = Color.fromRGBO(255, 112, 112, 1.0);
final locationInstance = Location();
const defaultEmoji = "🔮";
