# NEWSVOCA iPhone test setup

Windows cannot build or validate the iOS target. Complete these steps on a Mac with the latest
stable Flutter, Xcode, and CocoaPods installed.

## Required Firebase file

Before running the app, download the iOS `GoogleService-Info.plist` for Firebase project
`newswordapp-7a53b` and bundle identifier `com.example.wordapp`.

1. Place it at `ios/Runner/GoogleService-Info.plist`.
2. The Xcode project already references this path and includes it in the Runner target resources.
3. Open `ios/Runner.xcworkspace` in Xcode and confirm the reference is no longer shown in red.
4. Copy the plist's `REVERSED_CLIENT_ID` into `ios/Runner/Info.plist` as a URL scheme for Google
   Sign-In. Do not invent or copy a client ID from another Firebase app.

The Firebase file is intentionally ignored by Git and is not included in this repository. Transfer
it separately through a private channel and place it at the path above after cloning. If the project
is delivered as a ZIP, verify that the real file is included separately before handing it over.

## First run on a Mac

```sh
flutter doctor
flutter pub get
cd ios
pod install
cd ..
open ios/Runner.xcworkspace
```

In Xcode:

1. Select the Runner target.
2. Open **Signing & Capabilities** and select the friend's Apple Developer Team.
3. If Xcode reports that `com.example.wordapp` is unavailable to that Team, change the Runner
   bundle identifier and register/download a matching Firebase iOS app configuration first.
4. Connect the iPhone, enable Developer Mode, trust the Mac, select the iPhone, and Run.

After signing is configured, the app can also be launched with:

```sh
flutter run
```

## Fix `Module 'cloud_firestore' not found`

This usually means CocoaPods was not installed correctly or `Runner.xcodeproj` was opened instead
of the workspace.

```sh
flutter clean
flutter pub get
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
open ios/Runner.xcworkspace
```

Always open `Runner.xcworkspace` after `pod install`; do not build `Runner.xcodeproj` directly.

## Files to transfer

Keep `lib/`, `ios/`, `assets/`, `pubspec.yaml`, `pubspec.lock`, and
`lib/firebase_options.dart`. The real `ios/Runner/GoogleService-Info.plist` is Git-ignored and must
be supplied separately through an appropriate private channel. Build outputs such as `build/`,
`.dart_tool/`, `ios/Pods/`, and Xcode DerivedData are not required.
