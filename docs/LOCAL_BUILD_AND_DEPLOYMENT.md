# Local build and deployment

This guide covers local compilation, simulator installation, and deployment to a
physical Apple TV. The project uses an Xcode project (not Swift Package Manager)
and targets tvOS 17.0.

## Requirements

- macOS with Xcode 27.2 or newer, including the tvOS platform and simulator runtime;
- an Apple ID signed in to Xcode for device builds;
- an Apple TV 4K and USB-C network or Wi-Fi connectivity for hardware testing;
- Developer Mode enabled on the Apple TV when Xcode requests it.

The app bundle identifier is `org.community.wrestling-chronology.tvOS`. A physical
device build must be signed by a development team that can use this identifier.
If the identifier is not available to your team, set a unique bundle identifier
in Xcode before signing.

## Open the project

```sh
open WrestlingChronology-tvOS.xcodeproj
```

In Xcode, choose the `WrestlingChronology-tvOS` scheme. For a simulator run,
select an Apple TV simulator. For hardware deployment, select the connected Apple
TV in the run-destination menu and choose your team under the app target's
**Signing & Capabilities** settings.

The project contains a development-team value for the repository's original
environment. If you use another team, change the signing team locally in Xcode
or pass `DEVELOPMENT_TEAM` on the command line; do not commit personal signing
or provisioning changes.

## Signing-free SDK build

This verifies that the app compiles for the tvOS device SDK without requiring a
certificate or provisioning profile:

```sh
xcodebuild -project WrestlingChronology-tvOS.xcodeproj \
  -scheme WrestlingChronology-tvOS \
  -sdk appletvos \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

To keep all generated build data inside the repository's ignored `build/` folder:

```sh
xcodebuild -project WrestlingChronology-tvOS.xcodeproj \
  -scheme WrestlingChronology-tvOS \
  -sdk appletvos \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Run on a tvOS simulator

List available simulator devices and runtimes:

```sh
xcrun simctl list devices available
```

Build for a selected simulator. Replace the destination name with one shown by
the previous command if necessary:

```sh
xcodebuild -project WrestlingChronology-tvOS.xcodeproj \
  -scheme WrestlingChronology-tvOS \
  -configuration Debug \
  -destination 'platform=tvOS Simulator,name=Apple TV' \
  -derivedDataPath build/SimulatorDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Install and launch the resulting app on the currently booted simulator:

```sh
xcrun simctl install booted \
  build/SimulatorDerivedData/Build/Products/Debug-appletvsimulator/WrestlingChronology-tvOS.app
xcrun simctl launch booted org.community.wrestling-chronology.tvOS
```

The same install and launch operations are available from Xcode's Run button.
The simulator is useful for navigation, focus, caching, and fixture validation;
real playback and hardware-specific behavior must be checked on an Apple TV.

## Deploy to a physical Apple TV

1. Sign in to Xcode with an Apple ID under **Xcode > Settings > Accounts**.
2. Connect the Apple TV and accept the trust/developer prompts on both devices.
3. In the app target's **Signing & Capabilities**, select a development team and
   resolve any bundle-identifier or provisioning errors.
4. Select the Apple TV as the run destination and press **Run**.

For a command-line device build, first obtain the device identifier from Xcode's
**Window > Devices and Simulators**. Then run:

```sh
xcodebuild -project WrestlingChronology-tvOS.xcodeproj \
  -scheme WrestlingChronology-tvOS \
  -configuration Debug \
  -destination 'platform=tvOS,id=<APPLE_TV_UDID>' \
  DEVELOPMENT_TEAM=<TEAM_ID> \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  build
```

Xcode is the recommended deployment path because it handles signing, pairing,
installation, and launching together. If a signed `.app` is already available,
Xcode 15 or newer also provides the command-line device tools:

```sh
xcrun devicectl device install app \
  --device <APPLE_TV_UDID> \
  path/to/WrestlingChronology-tvOS.app
xcrun devicectl device process launch \
  --device <APPLE_TV_UDID> \
  org.community.wrestling-chronology.tvOS
```

## Create a local archive

An archive is useful for repeatable device installation or later export. It
requires a valid signing team and provisioning setup:

```sh
xcodebuild -project WrestlingChronology-tvOS.xcodeproj \
  -scheme WrestlingChronology-tvOS \
  -configuration Release \
  -destination 'generic/platform=tvOS' \
  -archivePath build/WrestlingChronology-tvOS.xcarchive \
  DEVELOPMENT_TEAM=<TEAM_ID> \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  archive
```

The archive is written under the ignored `build/` directory. Open it in Xcode's
Organizer to validate signing, export an installable package, or distribute it
through the appropriate Apple workflow. Do not commit archives, provisioning
profiles, certificates, or export credentials.

## Validation after deployment

After the app launches, use the hardware checklist in [Testing](TESTING.md).
For automated tests, follow the simulator test command and coverage notes in
that document. In particular, record simulator results separately from physical
Apple TV playback results: the simulator may not reproduce network playback,
Siri Remote behavior, or device signing conditions.

## Common issues

- **No simulator destination:** install a tvOS simulator runtime from Xcode's
  Components settings and retry `xcrun simctl list devices available`.
- **Signing or provisioning failure:** select your team for the app target,
  confirm that the bundle identifier is available, and pair the Apple TV in
  Xcode's Devices and Simulators window.
- **`simctl` cannot connect:** restart the Simulator app and Xcode, then verify
  that CoreSimulatorService is running and a device is booted.
- **Playback works only on one environment:** confirm network access and test
  the provider URL on the actual Apple TV; a successful compile or simulator
  launch does not prove provider playback availability.
