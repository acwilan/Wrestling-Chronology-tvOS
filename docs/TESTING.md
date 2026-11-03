# Testing

## Automated

Run the signing-free build:

```sh
xcodebuild -project WrestlingChronology-tvOS.xcodeproj \
  -scheme WrestlingChronology-tvOS \
  -sdk appletvos \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

For a restricted development host that cannot write Xcode's default DerivedData
directory, use the same build with `SWIFT_ENABLE_EXPLICIT_MODULES=NO` and an
explicit writable derived-data path, for example:

```sh
xcodebuild -project WrestlingChronology-tvOS.xcodeproj \
  -scheme WrestlingChronology-tvOS \
  -sdk appletvos \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  -derivedDataPath /private/tmp/wc-derived \
  build
```

`build-for-testing` also compiles the XCTest bundle. Test execution still needs
a concrete tvOS simulator or connected Apple TV destination.

Run tests on an installed tvOS simulator:

```sh
xcodebuild -project WrestlingChronology-tvOS.xcodeproj \
  -scheme WrestlingChronology-tvOS \
  -destination 'platform=tvOS Simulator,name=Apple TV' test
```

Tests cover manifest/schema validation, SHA-256 and byte-count rejection, stale revisions, merge and retirement semantics, same-day ordering, history migration/resume/completion, provider URL filtering, and resolver behavior with sanitized fixtures.

## Hardware checklist

On an Apple TV 4K, verify:

1. first launch shows bundled fixtures offline;
2. manifest refresh and one-company lazy download work;
3. WCW 1997 and a second company browse by year and search correctly;
4. Internet Archive playback starts without a whole-file download;
5. Siri Remote pause, seek, Menu, resume, and focus restoration work;
6. long playback persists position on interruption and exit;
7. a completed episode marks watched and autoplay advances exactly once;
8. a failed source shows an actionable error and tries the next eligible source;
9. a corrupt or stale pack leaves the previous cache intact;
10. reset-data confirmation removes local catalogue/history state only.

The development host currently has the tvOS SDK but may not have a functioning CoreSimulatorService. Simulator and physical-device playback results must be recorded separately from the compile/test results.
