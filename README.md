# Wrestling Chronology for tvOS

Wrestling Chronology for tvOS is an unofficial, community-maintained native Apple TV port of [Wrestling Chronology](https://github.com/deklol/Wrestling-Chronology), created by digitalm1nd. It is not affiliated with or endorsed by Apple, WWE, WCW, ECW, TNA, or any other promotion.

The app is GPL-3.0. It reads the upstream public catalogue, caches verified metadata locally, and plays compatible public provider URLs directly. It does not bundle or redistribute recordings.

## Current status

The MVP includes:

- typed catalogue models and deterministic chronological ordering;
- lazy manifest/company-pack loading with ETag, byte-count, SHA-256, schema, revision, and URL validation;
- automatic online refresh after bundled-fixture startup, while retaining offline browsing when refresh fails;
- atomic last-known-good catalogue caching and offline browsing;
- continue watching, watched state, resume position, source preference, and autoplay settings;
- SwiftUI company/year/search/detail browsing designed for Siri Remote focus navigation;
- direct Internet Archive MP4 playback through AVKit, including multipart queue playback;
- preflight AVAsset playability checks, bounded provider waits, and actionable playback failures;
- visible-but-unsupported YouTube entries, so the app never performs unapproved extraction;
- provider handoff buttons for unsupported YouTube, Dailymotion and OK.ru entries, which ask tvOS to open the public provider page in an installed app or URL handler;
- an About screen with upstream attribution and licence notices.

Dailymotion and OK.ru resolver boundaries are present but disabled by default until provider-specific tvOS validation and permission review are complete. Their public pages can still be handed off from episode details when the Apple TV has a compatible URL handler. This is not stream extraction or native playback. WCtv, community APIs, artwork reuse, and iCloud sync are intentionally not exposed in this MVP.

## Build

Open `WrestlingChronology-tvOS.xcodeproj` in Xcode 27.2 or newer. The deployment target is tvOS 17.0.

For a signing-free SDK build:

```sh
xcodebuild -project WrestlingChronology-tvOS.xcodeproj \
  -scheme WrestlingChronology-tvOS \
  -sdk appletvos \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

Select an Apple TV simulator or connected Apple TV 4K in Xcode for interactive testing. The simulator may not be available on every development host; real playback validation requires a signed device build and network access.

## Data and rights

The default feed is the upstream manifest:

`https://raw.githubusercontent.com/deklol/Wrestling-Chronology/main/catalogue/manifest.json`

The app validates the manifest and every downloaded pack before replacing a cache. Public media remains hosted by its provider and may disappear or be restricted. Playback does not bypass DRM, authentication, paywalls, or geographic restrictions.

See:

- [Local build and deployment](docs/LOCAL_BUILD_AND_DEPLOYMENT.md)
- [Public distribution without the App Store](docs/DISTRIBUTION.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Upstream compatibility](docs/UPSTREAM_COMPATIBILITY.md)
- [Testing](docs/TESTING.md)
- [Roadmap](docs/ROADMAP.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

## Attribution

Catalogue semantics and provider source configuration are adapted from the upstream GPL-3.0 project. The tvOS port is a separate project and marks its adaptations in source documentation. Upstream repository: <https://github.com/deklol/Wrestling-Chronology>.
