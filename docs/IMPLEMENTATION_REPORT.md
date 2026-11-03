# MVP implementation report

## Implemented

- Native SwiftUI tvOS app targeting tvOS 17.0 with a hand-authored Xcode project.
- Typed upstream manifest/pack models, lazy company loading, fixture fallback,
  ETag metadata, SHA-256 and byte validation, schema/revision checks, atomic
  cache replacement, rollback, and explicit `retiredSources` handling.
- Chronological company/year browsing, same-day ordering, search, episode detail,
  continue watching, watched indicators, settings, About, and neutral artwork.
- Actor-backed Codable history with migration, resume threshold, completion,
  periodic progress saves, preferred source persistence, and autoplay state.
- Internet Archive direct MP4 playback and multipart `AVQueuePlayer` playback.
  Playback now preflights the first asset with a bounded AVAsset load and reports
  provider failures instead of entering an indefinite loading state.
  YouTube remains visible but explicitly unsupported. Dailymotion and OK.ru
  parsing boundaries are present but disabled pending provider validation.
- Sanitized fixtures and XCTest coverage for ordering, catalogue verification,
  history behavior, source validation, and provider metadata parsing.

## Verification

- `xcodebuild ... -derivedDataPath /private/tmp/wc-final-app build`: **BUILD SUCCEEDED**.
- `xcodebuild ... -derivedDataPath /private/tmp/wc-final-tests build-for-testing`:
  **TEST BUILD SUCCEEDED**; both XCTest files compile.
- Fixture JSON and `Info.plist` lint successfully.
- Bundled fixtures automatically attempt an online manifest/pack refresh after
  startup; a failed refresh remains explicitly offline rather than masquerading
  as playable media.
- Test execution is pending because CoreSimulatorService is incompatible with
  the installed Xcode build and no concrete tvOS destination is available here.

## Remaining risks and next work

1. Validate Archive MIME/codec/range behavior, multipart transitions, long-session
   seeking, interruption/resume, and source fallback on an Apple TV 4K.
2. Validate the remote manifest and WCW 1997 plus a second promotion on hardware;
   current offline fixtures are deliberately small.
3. Obtain provider-specific permission/contract clarification before enabling
   Dailymotion or OK.ru playback.
4. Confirm WCtv/community API reuse terms with the upstream maintainer before
   adding those optional features.
