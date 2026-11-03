# Public distribution without the App Store

Wrestling Chronology for tvOS is distributed as community software. The public
route is **user-signed sideloading**: the project publishes source and an
unsigned release artifact, and each user signs it with their own Apple account
before installing it on an Apple TV.

The project must not publish an IPA signed with the maintainer's development or
Ad Hoc provisioning profile. A signed build tied to one Apple Developer team is
not the public distribution model for this project.

## Distribution matrix

| Route | Audience | Status | Main limitation |
| --- | --- | --- | --- |
| Xcode self-signing | Public community | Recommended | Requires a Mac, Xcode, pairing, and an Apple account |
| Apple Configurator | Public community | Optional | Still requires a correctly signed IPA and paired Apple TV |
| AltServer/other sideloaders | Public community | Optional, unofficial | tvOS support and renewal behavior can change after OS/tool updates |
| Ad Hoc | Maintainers and invited testers | Controlled only | Apple TV device IDs must be registered; limited to 100 devices per product family per membership year |
| TestFlight | Temporary beta | Contingency only | First external build requires App Review; builds expire after 90 days |
| Alternative marketplace | tvOS public store | Not supported | Apple's current EU marketplace capability is for iOS/iPadOS, not tvOS |

Apple's permitted distribution channels and registered-device rules are
described in the [Apple Developer Program Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/),
[registered-device documentation](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices),
and [device limits](https://developer.apple.com/help/account/devices/devices-overview).

## Install with Xcode

This is the canonical path because it uses Apple's supported tvOS device
workflow and lets the user sign with their own team.

1. Install Xcode with the tvOS platform and pair the Apple TV in **Window >
   Devices and Simulators**.
2. Clone the repository and open
   `WrestlingChronology-tvOS.xcodeproj`.
3. Select the `WrestlingChronology-tvOS` target, choose your own team under
   **Signing & Capabilities**, and use a unique bundle identifier if Xcode says
   the repository identifier is unavailable.
4. Select the paired Apple TV and press **Run**.

For a release artifact downloaded from GitHub, use Xcode's device window to
install the correctly signed `.ipa`, or build from source and let Xcode sign it
automatically. An unsigned IPA from a release cannot launch until it has been
signed for the installing user's Apple team.

The project also supports the command-line device flow documented in
[`LOCAL_BUILD_AND_DEPLOYMENT.md`](LOCAL_BUILD_AND_DEPLOYMENT.md).

## Optional sideloading tools

The release workflow publishes `apps.json` as a GitHub Release asset. The
stable feed URL is:

```text
https://github.com/acwilan/Wrestling-Chronology-tvOS/releases/latest/download/apps.json
```

Add that URL to a tvOS-capable signing/sideloading tool if the tool supports
AltStore-format sources. The feed is only metadata pointing to the unsigned
release IPA; it is not an Apple-authorized alternative marketplace.

AltServer documents direct `.ipa` sideloading to Apple TV, but Apple TV pairing
with Xcode is required first and sideloaded apps may need periodic
reinstallation. See the [AltServer release notes](https://github.com/altstoreio/FAQ/blob/main/release-notes/altserver.md).

If a third-party tool fails after a tvOS update, use Xcode self-signing. Do not
send the project maintainer's certificate, private key, provisioning profile, or
Apple account credentials to a sideloading service.

## Ad Hoc testing

Ad Hoc is for maintainers, contributors, and invited testers whose Apple TV
device IDs are known. It is not the public-community route.

The maintainer must register each Apple TV in the Apple Developer account, create
an Ad Hoc tvOS provisioning profile, export a signed IPA, and distribute it only
to that controlled cohort. Apple currently allows up to 100 registered Apple TVs
per product family per membership year. Device registrations and profiles must
be renewed as the membership and profile validity require.

## TestFlight contingency

TestFlight can be used for a temporary beta only if the build is acceptable for
TestFlight review. External testing supports public links and up to 10,000
testers, but the first external build requires App Review and each build is
available for up to 90 days. It is not the primary plan while the known blocker
is a rights/content issue.

## Rights and provenance checklist

Before publishing a release, verify:

- the catalogue metadata and schema are permitted for reuse from the upstream
  project;
- artwork and logos are either original, licensed, or used under a documented
  permission basis;
- provider URLs remain public links and are not replaced by extracted,
  proxied, DRM-bypassed, or authenticated media;
- the release does not bundle or redistribute wrestling recordings;
- user-visible attribution, GPL notices, provider disclaimers, and
  non-affiliation language are present;
- release notes do not imply endorsement by Apple, WWE, WCW, ECW, TNA, or any
  other promotion.

Sideloading does not cure a rights problem. It only changes how a user installs
the software.

## Troubleshooting

### “No signing team” or provisioning errors

Select the installing user's team in Xcode. If the default bundle identifier is
already registered by another team, change it locally to a unique identifier.
Do not commit personal team IDs or provisioning files.

### Apple TV is not visible

Pair it in **Window > Devices and Simulators**, approve trust prompts, keep the
Mac and Apple TV on the same network when using wireless pairing, and retry.
Some third-party tools require a fresh Xcode pairing after a tvOS update.

### The app expired or stopped launching

The provisioning profile or signing certificate has expired. Rebuild or
reinstall using the same user's Apple account. Free/personal provisioning can
require frequent renewal; a paid Apple Developer membership is more practical
for maintainers and long-lived testing.

### The app installs but playback fails

Installation does not guarantee provider availability. Check the provider URL,
network access, codec compatibility, geographic restrictions, and the app's
visible playback error. The app does not bypass DRM, paywalls, authentication,
or provider restrictions.
