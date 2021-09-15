import 'package:binder/binder.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/player_state.dart';
import 'package:voice_outliner/views/notes_view.dart';
import 'package:voice_outliner/views/outlines_view.dart';

final routes = {
  "/": (_) => const OutlinesView(),
  "/notes": (_) => const NotesViewWrapper()
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences sharedPrefs = await SharedPreferences.getInstance();
  runApp(BinderScope(
      child: VoiceOutlinerApp(
    sharedPreferences: sharedPrefs,
  )));
}

class VoiceOutlinerApp extends StatefulWidget {
  final SharedPreferences sharedPreferences;
  const VoiceOutlinerApp({Key? key, required this.sharedPreferences})
      : super(key: key);

  @override
  _VoiceOutlinerAppState createState() => _VoiceOutlinerAppState();
}

class _VoiceOutlinerAppState extends State<VoiceOutlinerApp> {
  String? lastRoute;
  String? lastOutline;

  // @override
  // void didChange

  @override
  void initState() {
    super.initState();
    setState(() {
      lastRoute = widget.sharedPreferences.getString("last_route");
      lastOutline = widget.sharedPreferences.getString("last_outline");
    });
  }

  Future<void> saveRoute(RouteSettings route) async {
    await widget.sharedPreferences.setString("last_route", route.name!);
    if (route.arguments != null) {
      await widget.sharedPreferences.setString(
          "last_outline", (route.arguments as NotesViewArgs).outlineId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LogicLoader(
        refs: [dbRepositoryRef, playerLogicRef],
        builder: (context, loading, child) {
          if (loading) {
            // TODO: black screen
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return child!;
        },
        child: MaterialApp(
          title: 'Voice Outliner',
          // TODO: loader as disabled interaction - overlay
          onGenerateRoute: (RouteSettings route) {
            saveRoute(route);
            final rte = routes[route.name];
            if (rte == null) {
              throw ("Route null");
            }
            return MaterialPageRoute(
                builder: rte,
                settings: RouteSettings(
                    name: route.name,
                    arguments: route.arguments ??
                        (lastOutline != null
                            ? NotesViewArgs(lastOutline!)
                            : null)));
          },
          initialRoute: lastRoute ?? "/",
          theme: ThemeData(
              primarySwatch: Colors.deepPurple,
              primaryColor: const Color.fromRGBO(169, 129, 234, 1)),
          color: const Color.fromRGBO(169, 129, 234, 1),
        ));
  }
}
