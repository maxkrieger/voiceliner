# Voiceliner

<img src="assets/icon/icon.png" width="200" />

A nested, rapid voice memos for Android and iOS. Written in Flutter.

## Screenshots


<img src="assets/screenshots/1.png" width="300" />
<img src="assets/screenshots/2.png" width="300" />
<img src="assets/screenshots/3.png" width="300" />

## Contributing & License

This project is AGPLv3 but with an exception for the App Store. [Learn More](CONTRIBUTING.md)

## Building

* Install flutter
* `flutter run lib/main.dart` 

If running Android and need transcription:

* `flutter run --dart-define="AZURE_SPEECH_KEY=MyAzureAPIKey"`

## Rebuilding Icons

Place a 1024x1024 `icon.png` in `assets/icon/icon.png` and run

```
flutter pub run flutter_launcher_icons:main
```

## Deploying

* `android/key.properties`:
```
  storePassword=keystore password
  keyPassword=key password
  keyAlias=key alias
  storeFile=/keystore/location
```


|Env Var| Value                                                                                                                                                         |
|----|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
|AZURE_SPEECH_KEY| api key for Azure speech to text services (https://docs.microsoft.com/en-us/azure/cognitive-services/speech-service/overview#try-the-speech-service-for-free) |
|APPLE_ID| apple account email"                                                                                                                                          
|APP_IDENTIFIER| ios com.blabla.blabla                                                                                                                                         |
|PLAY_APP_IDENTIFIER| android com.blablabla.bla                                                                                                                                     |
|ITC_TEAM_ID| documented in fastlane                                                                                                                                        |
|TEAM_ID| documented in fastlane                                                                                                                                        |
|MATCH_GIT| github SSH URI for fastlane match                                                                                                                             |
|MATCH_PASSWORD| documented in fastlane                                                                                                                                        |
|FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD| app specific password for fastlane                                                                                                                            |
|FASTLANE_USER| documented in fastlane                                                                                                                                        |
|FASTLANE_PASSWORD| documented in fastlane                                                                                                                                        |
|FASTLANE_SESSION| documented in fastlane                                                                                                                                        |
|GOOGLE_PLAY_JSON_CONTENT| base64 encoded json keys for google play fastlane                                                                                                             |
|KEYSTORE| base64 encoded keystore.jks                                                                                                                                   |
|KEY_PROPERTIES| key.properties seen above                                                                                                                                     |
|SSH_PRIVATE_KEY| for github access                                                                                                                                             |
|SENTRY_DSN| for sentry logging                                                                                                                                            |

