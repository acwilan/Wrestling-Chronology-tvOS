#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT_DIR=${1:-"$PROJECT_DIR/build/release"}
VERSION=${2:-0.1.0}
BUILD_NUMBER=${3:-1}
DERIVED_DATA_DIR="$PROJECT_DIR/build/ReleaseDerivedData"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Release-appletvos/WrestlingChronology-tvOS.app"

case "$OUTPUT_DIR" in
  /*) ;;
  *) OUTPUT_DIR="$PROJECT_DIR/$OUTPUT_DIR" ;;
esac

IPA_PATH="$OUTPUT_DIR/WrestlingChronology-tvOS.ipa"

mkdir -p "$OUTPUT_DIR"

xcodebuild \
  -project "$PROJECT_DIR/WrestlingChronology-tvOS.xcodeproj" \
  -scheme WrestlingChronology-tvOS \
  -configuration Release \
  -sdk appletvos \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

if [ ! -d "$APP_PATH" ]; then
  echo "Expected app was not produced: $APP_PATH" >&2
  exit 1
fi

# A public release must never contain the maintainer's development or Ad Hoc
# signature. Users sign this artifact with their own Apple Developer team.
if codesign --verify --deep "$APP_PATH" >/dev/null 2>&1; then
  echo "Refusing to package a signed app: $APP_PATH" >&2
  exit 1
fi

STAGE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/wrestling-chronology-tvos.XXXXXX")
trap 'rm -rf "$STAGE_DIR"' EXIT HUP INT TERM
mkdir -p "$STAGE_DIR/Payload"
cp -R "$APP_PATH" "$STAGE_DIR/Payload/"

(
  cd "$STAGE_DIR"
  zip -qry "$IPA_PATH" Payload
)

SHA256=$(shasum -a 256 "$IPA_PATH" | awk '{print $1}')
SIZE=$(wc -c < "$IPA_PATH" | tr -d ' ')
cat > "$OUTPUT_DIR/WrestlingChronology-tvOS.sha256" <<EOF
$SHA256  WrestlingChronology-tvOS.ipa
EOF
cat > "$OUTPUT_DIR/release-metadata.json" <<EOF
{
  "name": "Wrestling Chronology for tvOS",
  "bundleIdentifier": "org.community.wrestling-chronology.tvOS",
  "version": "$VERSION",
  "buildVersion": "$BUILD_NUMBER",
  "minOSVersion": "17.0",
  "size": $SIZE,
  "sha256": "$SHA256"
}
EOF

echo "Created unsigned artifact: $IPA_PATH"
echo "SHA-256: $SHA256"
