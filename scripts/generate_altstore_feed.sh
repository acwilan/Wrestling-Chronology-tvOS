#!/bin/sh

set -eu

if [ "$#" -ne 7 ]; then
  echo "usage: $0 VERSION BUILD_NUMBER DATE DOWNLOAD_URL SIZE SHA256 OUTPUT_FILE" >&2
  exit 2
fi

VERSION=$1
BUILD_NUMBER=$2
DATE=$3
DOWNLOAD_URL=$4
SIZE=$5
SHA256=$6
OUTPUT_FILE=$7

mkdir -p "$(dirname -- "$OUTPUT_FILE")"

jq -n \
  --arg version "$VERSION" \
  --arg buildVersion "$BUILD_NUMBER" \
  --arg date "$DATE" \
  --arg downloadURL "$DOWNLOAD_URL" \
  --arg sha256 "$SHA256" \
  --argjson size "$SIZE" \
  '{
    name: "Wrestling Chronology tvOS",
    identifier: "org.community.wrestling-chronology.tvOS.source",
    sourceURL: "https://github.com/acwilan/Wrestling-Chronology-tvOS",
    apps: [{
      name: "Wrestling Chronology",
      bundleIdentifier: "org.community.wrestling-chronology.tvOS",
      developerName: "Wrestling Chronology community",
      subtitle: "Unofficial community Apple TV port",
      localizedDescription: "A community-maintained tvOS catalogue and player. This feed is for user-signed sideloading and is not an Apple-authorized alternative marketplace.",
      iconURL: "https://raw.githubusercontent.com/acwilan/Wrestling-Chronology-tvOS/main/Assets.xcassets/AppIcon.brandassets/App%20Icon%20-%20App%20Store.imagestack/Front.imagestacklayer/Content.imageset/front.png",
      tintColor: "#1D1D1F",
      versions: [{
        version: $version,
        buildVersion: $buildVersion,
        date: $date,
        downloadURL: $downloadURL,
        size: $size,
        sha256: $sha256,
        minOSVersion: "17.0"
      }]
    }]
  }' > "$OUTPUT_FILE"
