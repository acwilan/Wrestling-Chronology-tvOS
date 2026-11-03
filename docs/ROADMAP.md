# Wrestling Chronology tvOS roadmap

This roadmap describes the intended evolution of the community-maintained tvOS port. It is deliberately separate from the original Android/Fire TV feature set: each provider and service must be technically feasible, permitted to reuse, and useful on Apple TV before it is enabled.

## Current milestone: catalogue and playback MVP

Status: implemented in the repository; physical Apple TV validation remains in progress.

- Native SwiftUI/tvOS 17 interface with Siri Remote focus navigation.
- Home screen, company libraries, year browsing, show filtering, search and episode details.
- Chronological ordering with deterministic same-day ordering.
- Remote manifest and lazy company-pack refresh with ETag support, byte-count and SHA-256 validation, revision checks, atomic replacement and last-known-good fallback.
- Bundled WCW/WWE metadata fixtures for offline first launch.
- Durable local history with resume position, completion state, progress indicators and reset controls.
- Internet Archive direct playback, multipart queue playback, AVPlayer preflight and actionable failure states.
- External provider handoff links for YouTube, Dailymotion and OK.ru where a public URL can be constructed.
- About screen, GPL-3.0 attribution and upstream project credit.

MVP validation still required:

- Install and exercise the current build on Apple TV 4K.
- Verify long-form and multipart Internet Archive playback, seeking, interruption/resume and provider failure fallback.
- Verify Siri Remote focus restoration, Menu/back behavior and overscan-safe layouts.
- Verify YouTube, Dailymotion and OK.ru links with the applications and URL handlers installed on the target Apple TV.
- Complete chronological next-episode autoplay rather than only exposing the setting and completion state.

## Next: finish the dependable daily-use experience

Priority: high.

1. Complete next-episode autoplay using the repository’s chronological successor, including multipart completion and a clear user opt-out.
2. Wire the preferred-source setting into source selection and add an explicit source picker on episode detail.
3. Improve playback diagnostics for HTTP range failures, unsupported codecs, expired URLs and partial queue failures.
4. Add a lightweight device test checklist to the release workflow and capture screenshots from a real Apple TV build.
5. Add focused tests for autoplay selection, external URL handoff mapping and source preference persistence.
6. Improve performance for very large company packs through measured lazy parsing, pagination and memory profiling.

## Provider compatibility

Priority: medium, subject to provider terms and real-device testing.

- Internet Archive: verify representative MP4/HLS-compatible files, HTTP range behavior, seeking and multipart transitions on Apple TV hardware.
- Dailymotion: only enable native HLS resolution after confirming the metadata contract, owner validation, URL expiry handling and permitted client access.
- OK.ru: only enable native HLS resolution after validating public embed metadata, host validation, headers and playback on hardware. DASH remains out of scope unless a safe native path is established.
- YouTube: keep public-page handoff as the default. Do not port NewPipe extraction, signature deciphering or a proxy. Revisit only if an approved tvOS playback or app handoff path is available.

## Feature milestone: richer browsing and playback controls

Priority: medium.

- Month-level browsing and additional show/category filters.
- Per-episode source selection with availability explanations.
- Quality selection where the provider exposes stable, permitted variants.
- Optional widescreen/stretch preference only where it behaves predictably with AVPlayer.
- Better artwork support using assets with established reuse rights or original neutral artwork.
- More detailed watched-state controls, including explicit “mark unwatched”.
- Accessibility review for labels, contrast, focus indication and long titles.

## Feature milestone: optional WCtv integration

Priority: deferred.

WCtv remains omitted from the UI until its schedule and playback contracts are confirmed with the upstream maintainer. Before implementation:

- Document the API endpoints, authentication model, rate limits and reuse permission.
- Confirm whether schedule data is public, stable and appropriate for a tvOS client.
- Define failure, stale-data and timezone behavior.
- Keep the feature behind a capability flag and ensure the core catalogue works without it.

Potential scope after confirmation:

- Current schedule and programme guide.
- Channel browsing and local-time display.
- Live playback only through a provider-supported AVPlayer-compatible path.

## Feature milestone: community services

Priority: deferred.

Do not add nonfunctional buttons for likes, views, comments or replies. Before implementation:

- Confirm API ownership and permission to reuse from tvOS.
- Define privacy, moderation, abuse reporting and account requirements.
- Decide whether anonymous browsing is possible and how credentials are stored.
- Add rate limiting, offline behavior and clear user controls.

## Release readiness

Priority: after the above core work.

- Add a documented signing and sideloading path for developer-owned Apple TVs.
- Test clean installation, upgrade, rollback and cache migration.
- Audit third-party notices, provider links, artwork and attribution.
- Add privacy documentation for local history and any future network services.
- Verify all user-visible provider and rights language.
- Evaluate App Store requirements separately; no approval or distribution outcome should be assumed.

## Explicit non-goals

- Hosting or redistributing wrestling recordings.
- DRM bypass, authentication bypass, paywall bypass or geographic restriction bypass.
- A general-purpose media proxy.
- Recreating the Android ingestion pipeline in the tvOS app.
- Porting Android-specific extraction libraries solely for feature parity.
- Enabling WCtv or community APIs without confirmed contracts and permission.
- iCloud sync before local history and privacy behavior are stable.
