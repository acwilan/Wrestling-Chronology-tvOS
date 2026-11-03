# Architecture

## Boundaries

The project uses source groups rather than external packages so the app remains easy to build on a clean Xcode installation.

- `CatalogDomain`: Codable catalogue types, source identity, validation values, and chronological ordering.
- `CatalogRepository`: manifest and pack transport, conditional requests, verification, merge, cache replacement, and fixture fallback.
- `History`: actor-isolated durable watch state and migration.
- `Playback`: provider capability checks, source resolution, AVPlayer queue construction, resume, progress, fallback, and autoplay.
- `Features`: SwiftUI view models and remote-first screens.
- `WCtv`: reserved boundary; no API calls or nonfunctional controls are shipped in this MVP.

## Catalogue flow

1. The repository loads a small bundled fixture immediately so the UI has a useful offline state.
2. It requests the upstream manifest with `If-None-Match` when an ETag is known.
3. A selected company pack is fetched lazily.
4. Raw bytes are bounded, counted, hashed with SHA-256, and decoded off the main actor.
5. Validation rejects unsupported schema versions, wrong companies, stale revisions, duplicate IDs, invalid dates, untrusted URLs, and unlisted provider identities.
6. A valid pack is merged with the last-known-good cache. Missing rows never delete cached rows; only explicit `retiredSources` entries remove a source.
7. The resulting JSON is written through a temporary file and atomic replacement. A backup remains available if replacement or a later decode fails.

The repository never treats a failed provider scan or absent row as an implicit deletion.

## Playback flow

`EpisodeDetailView` asks `PlaybackCoordinator` for eligible sources. `SourceResolver` validates the provider and returns a `PlaybackPlan`. Internet Archive URLs become `AVPlayerItem`s in an `AVQueuePlayer`; multipart items are queued in catalogue order. `AVPlayerViewController` supplies system controls and Siri Remote seeking. Progress is persisted periodically and on dismissal. End-of-item marks completion and optionally advances to the next chronological episode.

YouTube is represented in the domain and UI but returns an explicit unsupported error. No extraction, signature deciphering, DRM bypass, proxy, or authentication flow is included.

## Persistence

Settings use `UserDefaults`. Watch records use a versioned Codable file in Application Support, written by `HistoryStore` as an actor. Writes use a temporary file and replacement. Migration code is keyed by file schema version and preserves stable episode identity as `companyID + episodeID`.
