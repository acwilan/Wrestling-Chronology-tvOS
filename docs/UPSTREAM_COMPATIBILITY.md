# Upstream compatibility

Reconnaissance was performed against the upstream `main` branch and its canonical feed:

`https://raw.githubusercontent.com/deklol/Wrestling-Chronology/main/catalogue/manifest.json`

## Observed schema

The manifest has `schemaVersion: 1` and a `companies` object. Each company entry has `url`, `sha256`, `bytes`, and `revision`.

A company pack has `schemaVersion`, `company`, `revision`, `sources`, `retiredSources`, and `catalogue`. The catalogue contains `episodes`, `eventCalendar`, `playlists`, `archiveItems`, `showArtwork`, `sourceAssignments`, and optional history metadata.

Episode fields observed in the WCW and WWE packs include `id`, `date`, `year`, `show`, `title`, `description`, `category`, `duration`, `thumbnail`, `poster`, `part`, `listedParts`, `discoveredAt`, `aliases`, and `sources`.

Source types observed are `archive`, `youtube`, and `okru`; the schema also describes `dailymotion`. Archive sources may include `url`, `urls`, `filename`, `bytes`, `duration`, `height`, `programme`, `creator`, and language metadata. YouTube sources include `videoId`, `channelId`, `title`, `duration`, and optional playlist/direct metadata. OK.ru sources include `videoId`, `owner`, and catalogue metadata.

## Compatibility decisions

- Stable upstream episode IDs are preserved. Date/show is not used as a universal identity because PPVs, preshows, doubleheaders, and corrections may share a date.
- Date ordering is lexicographic ISO date order followed by explicit show rank, `eventOrder` when present, title, and ID. The tvOS client does not infer dates from titles.
- Missing rows and missing source configuration do not delete local entries. `retiredSources` is the only accepted source-removal mechanism.
- Archive playback is implemented first using direct HTTPS media URLs and AVPlayer. Multipart URLs are queued without downloading the complete recording.
- YouTube sources remain visible but unsupported because the Android extractor is not a permitted tvOS playback strategy for this project.
- Dailymotion metadata resolution and OK.ru public embed parsing are isolated behind disabled capabilities until sanitized fixtures and real-device playback checks pass.
- Artwork URLs are treated as optional metadata. No upstream logos, posters, thumbnails, or branded icons are bundled by this port.

## Representative samples

The current catalogue includes WCW 1997 broadcasts and the same date can contain Saturday Night, Pro, Worldwide, Nitro, and a PPV as separate episodes. A WCW 1990-07-07 PPV entry demonstrates multiple source providers, while a WCW Pro entry demonstrates a direct Internet Archive MP4 source. WWE is substantially larger than WCW, so JSON parsing and UI lists are kept off the main actor and use lazy views.
