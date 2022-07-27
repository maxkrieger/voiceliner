import 'dart:io';

import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_outliner/consts.dart';
import 'package:voice_outliner/state/player_state.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({Key? key}) : super(key: key);

  @override
  _OnboardingViewState createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  SharedPreferences? sharedPreferences;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      sharedPreferences = await SharedPreferences.getInstance();
      setState(() {});
    });
  }

  Future<void> enableLocation() async {
    try {
      bool permissioned = await locationInstance.requestService();
      if (!permissioned) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't get location")));
        return;
      }
      final testLoc = await locationInstance.getLocation();
      if (testLoc.latitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't get location")));
        return;
      }
      setState(() {
        sharedPreferences?.setBool(shouldLocateKey, true);
      });
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Couldn't get location")));
    }
  }

  void onDone() {
    Navigator.pushNamedAndRemoveUntil(
        context,
        Platform.isIOS
            ? "/transcription_setup_ios"
            : "/transcription_setup_vosk",
        (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    bool playerReady = context.select<PlayerModel, bool>(
        (value) => value.playerState == PlayerState.ready);
    bool locationOn = sharedPreferences?.getBool(shouldLocateKey) ?? false;
    return IntroductionScreen(
      dotsDecorator: const DotsDecorator(activeColor: classicPurple),
      showDoneButton: true,
      showNextButton: true,
      isTopSafeArea: true,
      next: Text(
        "Next",
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      done: Text(
        "Done",
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      onDone: onDone,
      pages: [
        PageViewModel(
            title: "Welcome to Voiceliner",
            bodyWidget: Column(children: [
              const Text(
                "Record your voice as structured notes.",
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              const Text(
                "Auto-transcribe them into an outline.",
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                  onPressed: playerReady
                      ? null
                      : () {
                          context.read<PlayerModel>().tryPermission();
                        },
                  child: Text(
                      playerReady ? "all set!" : "grant microphone access"))
            ]),
            image: Center(
                child: Image.asset(
              "assets/onboarding/1.png",
            ))),
        PageViewModel(
          image: Center(
              child: Image.asset(
            "assets/onboarding/2.png",
          )),
          title: "Tap and hold the microphone to record notes",
          bodyWidget: Column(children: const [
            Text(
              "While holding, drag up to change the temperature (color) of the note.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 15),
            Text(
              "Tap and hold anywhere else to create a text-only note.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ]),
        ),
        PageViewModel(
            title: "Swipe left or right to indent notes",
            body: "Drag them to reorder.",
            image: Center(
                child: Image.asset(
              "assets/onboarding/3.png",
            ))),
        PageViewModel(
            title: "See where you took notes",
            bodyWidget: Column(children: [
              const Text(
                "Attach your location, situate memories.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                  onPressed: locationOn ? null : enableLocation,
                  child: Text(locationOn ? "all set!" : "enable location"))
            ]),
            image: Center(
                child: Image.asset(
              "assets/onboarding/4.png",
            ))),
        PageViewModel(
            title: "Organize your notes into outlines",
            bodyWidget: Column(children: [
              const Text(
                "Set an emoji for each one.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: onDone, child: const Text("Let's go!"))
            ]),
            image: Center(
                child: Image.asset(
              "assets/onboarding/5.png",
            )))
      ],
    );
  }
}
