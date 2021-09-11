import 'package:binder/binder.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/player_state.dart';
import 'package:voice_outliner/views/notes_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BinderScope(child: VoiceOutlinerApp()));
}

class VoiceOutlinerApp extends StatelessWidget {
  const VoiceOutlinerApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return LogicLoader(
        refs: [dbRepositoryRef, playerLogicRef],
        builder: (context, loading, child) {
          if (loading) {
            // TODO: black screen
            return Container();
          }
          return child!;
        },
        child: MaterialApp(
          title: 'Voice Outliner',
          home: const NotesView(),
          theme: ThemeData(
              primarySwatch: Colors.deepPurple,
              primaryColor: const Color.fromRGBO(169, 129, 234, 1)),
          color: const Color.fromRGBO(169, 129, 234, 1),
        ));
  }
}
