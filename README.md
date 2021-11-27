# Voiceliner

## Building
* `assets/speech_acct.json` needs to be a google speech to text service account credentials.

* `android/local.properties`:
```
sdk.dir=/my/android.sdk/dir
flutter.sdk=/my/flutter/sdk/dir
flutter.buildMode=release
flutter.versionName=1.5.3
flutter.versionCode=24
```

## Deploying

* `android/key.properties`:
```
  storePassword=keystore password
  keyPassword=key password
  keyAlias=key alias
  storeFile=/keystore/location
```


|Env Var|Value|
|----|----|
|APPLE_ID|apple account email"
|APP_IDENTIFIER|ios com.blabla.blabla|
|PLAY_APP_IDENTIFIER|android com.blablabla.bla|
|ITC_TEAM_ID|documented in fastlane|
|TEAM_ID|documented in fastlane|
|MATCH_GIT|github SSH URI for fastlane match|
|MATCH_PASSWORD|documented in fastlane|
|FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD|app specific password for fastlane|
|FASTLANE_USER|documented in fastlane|
|FASTLANE_PASSWORD|documented in fastlane|
|FASTLANE_SESSION|documented in fastlane|
|GOOGLE_PLAY_JSON_CONTENT|base64 encoded json keys for google play fastlane|
|KEYSTORE|base64 encoded keystore.jks|
|KEY_PROPERTIES|key.properties seen above|
|SPEECH_JSON|base64 encoded google speech API json|
|SSH_PRIVATE_KEY|for github access|
|SENTRY_DSN|for sentry logging|

