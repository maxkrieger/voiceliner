import 'package:binder/binder.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:voice_outliner/repositories/db_repository.dart';
import 'package:voice_outliner/state/player_state.dart';
import 'package:voice_outliner/views/main_view.dart';

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
        child: const PlatformApp(
          title: 'Voice Outliner',
          home: MainView(),
          color: Color.fromRGBO(169, 129, 234, 1),
        ));
  }
}
