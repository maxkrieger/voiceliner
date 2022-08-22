# Put a .env in ios/fastlane with relevant variables described in README.md
flutter build ios --release --no-codesign
cd ios
bundle exec fastlane beta_local