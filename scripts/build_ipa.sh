#!/bin/bash
set -e

# StayTrack - Script de generación de IPAs (iOS & watchOS)
# Configuración: Release, sin requerimiento de firma estricta (ad-hoc)

CONFIGURATION="${1:-Release}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$PROJECT_DIR/DerivedData"
OUTPUT_DIR="$PROJECT_DIR/build/ipa"

echo "================================================"
echo "  StayTrack - Compilación de IPAs ($CONFIGURATION)"
echo "================================================"

mkdir -p "$OUTPUT_DIR"

# 1. Compilar iOS
echo "\n[1/4] Compilando StayTrack (iOS) en modo $CONFIGURATION..."
xcodebuild build \
  -scheme StayTrack \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "$DERIVED_DATA" > /dev/null

# 2. Empaquetar StayTrack.ipa
echo "[2/4] Empaquetando StayTrack.ipa..."
IOS_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphoneos/StayTrack.app"
TEMP_IOS="$OUTPUT_DIR/ios_temp"
rm -rf "$TEMP_IOS" "$OUTPUT_DIR/StayTrack.ipa"
mkdir -p "$TEMP_IOS/Payload"
cp -R "$IOS_APP" "$TEMP_IOS/Payload/"
(cd "$TEMP_IOS" && zip -qr "$OUTPUT_DIR/StayTrack.ipa" Payload)
rm -rf "$TEMP_IOS"
echo "  -> Generado: $OUTPUT_DIR/StayTrack.ipa"

# 3. Compilar watchOS
echo "\n[3/4] Compilando StayTrackWatch (watchOS) en modo $CONFIGURATION..."
xcodebuild build \
  -scheme StayTrackWatch \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=watchOS" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "$DERIVED_DATA" > /dev/null

# 4. Empaquetar StayTrackWatch.ipa
echo "[4/4] Empaquetando StayTrackWatch.ipa..."
WATCH_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION-watchos/StayTrackWatch.app"
TEMP_WATCH="$OUTPUT_DIR/watch_temp"
rm -rf "$TEMP_WATCH" "$OUTPUT_DIR/StayTrackWatch.ipa"
mkdir -p "$TEMP_WATCH/Payload"
cp -R "$WATCH_APP" "$TEMP_WATCH/Payload/"
(cd "$TEMP_WATCH" && zip -qr "$OUTPUT_DIR/StayTrackWatch.ipa" Payload)
rm -rf "$TEMP_WATCH"
echo "  -> Generado: $OUTPUT_DIR/StayTrackWatch.ipa"

echo "\n================================================"
echo "  IPAs generadas con éxito en: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.ipa
echo "================================================"
