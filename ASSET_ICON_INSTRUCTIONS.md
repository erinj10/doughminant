Place the attached Doughminant logo in the project and generate platform launcher icons

What to do (quick):

1. Save the provided logo image as:

   assets/app_icon.png

   Path from the project root: `assets/app_icon.png` (create the `assets` folder if it doesn't exist).

2. Install packages and run the launcher icon generator (PowerShell / Windows):

   flutter pub get
   # The package now recommends using `dart run` instead of `flutter pub run`.
   dart run flutter_launcher_icons:main

3. Check results:

   - Android: icons will be generated under `android/app/src/main/res/mipmap-*/ic_launcher.png` and adaptive icons in `mipmap-anydpi-v26`.
   - iOS/macOS: icons will be updated in the respective asset catalogs.
   - Windows/Linux: icons will be generated where supported by the package.

Notes & tips

- The `pubspec.yaml` has been updated to include the `flutter_launcher_icons` dev dependency and an `assets` entry for `assets/app_icon.png`. If you prefer not to add the dev dependency to `pubspec.yaml`, you can instead run the generator with a local config file or manually replace platform icon files.

-- If you want the generator to run automatically with a custom configuration (for example, different image path or to exclude a platform), edit the `flutter_icons` section in `pubspec.yaml` accordingly (see the package docs: https://pub.dev/packages/flutter_launcher_icons).

Windows note

- Recent versions of `flutter_launcher_icons` expect platform entries like `windows` (or `macos`) to be maps when you need to pass platform-specific options (for example `image_path`). If you previously used `windows: true`, the generator will fail with an "Unsupported value for \"windows\"" error — the project has been updated to use:

   windows:
      image_path: "assets/app_icon.png"

so the generator can run correctly on Windows.

- After running the generator, rebuild the app (e.g., `flutter run`) to see the new launcher icon on device/emulator.

Manual alternative

If you prefer to set the icons manually, place appropriately sized PNGs in the Android `mipmap-*` folders and update the iOS asset catalog (`ios/Runner/Assets.xcassets/AppIcon.appiconset/`).

If you'd like, I can also add a `flutter_icons` configuration block to `pubspec.yaml` that points to `assets/app_icon.png` so you can just run the generator; tell me if you want me to add it now and I'll update `pubspec.yaml` accordingly.
