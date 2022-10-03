# <img src="assets/icon/icon.png" width="100" /> Voiceliner

A voice memos-like for Android and iOS. Written in Flutter. Transcription on iOS uses the native transcription APIs (mostly on-device) and on Android, uses [Vosk](https://github.com/alphacep/vosk-api).
The codebase is still quite messy, but contributions welcome!

## Screenshots

<table>
  <tr>
    <td><img src="assets/screenshots/1.png" width="300" /></td>
    <td><img src="assets/screenshots/2.png" width="300" /></td>
    <td><img src="assets/screenshots/3.png" width="300" /></td>
  </tr>
</table>

## Contributing & License

This project is AGPLv3 but with an exception for the App Store. [Learn More](CONTRIBUTING.md)

## Building

- Install flutter
- `flutter run lib/main.dart`

## Rebuilding Icons

Place a 1024x1024 `icon.png` in `assets/icon/icon.png` and run

```
flutter pub run flutter_launcher_icons:main
```

## Deploying

- `android/key.properties`:

```
  storePassword=keystore password
  keyPassword=key password
  keyAlias=key alias
  storeFile=/keystore/location
```

For continuous integration:

| Env Var                                      | Value                                             |
|----------------------------------------------|---------------------------------------------------|
| APPLE_ID                                     | apple account email"                              |
| APP_IDENTIFIER                               | ios com.blabla.blabla                             |
| PLAY_APP_IDENTIFIER                          | android com.blablabla.bla                         |
| ITC_TEAM_ID                                  | documented in fastlane                            |
| TEAM_ID                                      | documented in fastlane                            |
| MATCH_GIT                                    | github SSH URI for fastlane match                 |
| MATCH_PASSWORD                               | documented in fastlane                            |
| FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD | app specific password for fastlane                |
| FASTLANE_USER                                | documented in fastlane                            |
| FASTLANE_PASSWORD                            | documented in fastlane                            |
| CONNECT_KEY                                  | app store connect .p8 file contents               |
| CONNECT_KEY_ID                               | app store connect key id                          |
| CONNECT_ISSUER_ID                            | app store connect key issuer id                   |
| GOOGLE_PLAY_JSON_CONTENT                     | base64 encoded json keys for google play fastlane |
| KEYSTORE                                     | base64 encoded keystore.jks                       |
| KEY_PROPERTIES                               | key.properties seen above                         |
| SSH_PRIVATE_KEY                              | for github access                                 |
| SENTRY_DSN                                   | for sentry logging                                |

For local deployment, populate the following `.env` files:

`ios/fastlane/.env`:

```
MATCH_GIT=...
APP_IDENTIFIER=...
CONNECT_KEY_ID=...
CONNECT_ISSUER_ID=...
```

`android/fastlane/.env`:

```
PLAY_APP_IDENTIFIER=...
```

`.env`:

```
SENTRY_DSN=...
```

You can then use `./deploy_ios.sh` and `./deploy_android.sh` to deploy to the app stores.


## Upgrading fastlane

```
ios/$ bundle update fastlane
android/$ bundle update fastlane
```

## Fastlane Match Notes

When running `fastlane match development --generate_apple_certs`, make sure to specify `*` for the bundle id, so that it can make provisioning profiles both for the `.debug` bundle identifier and the main one.