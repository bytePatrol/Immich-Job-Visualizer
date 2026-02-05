#!/bin/bash

# Create DMG installer for Immich Job Queue Visualizer
# Requires: create-dmg (brew install create-dmg), fileicon (brew install fileicon)

set -e

# Change to project root (parent of Scripts directory)
cd "$(dirname "$0")/.."

APP_NAME="Immich Job Queue Visualizer"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="ImmichJobQueueVisualizer.dmg"
VOLUME_NAME="Immich Job Queue Visualizer"

echo "📀 Creating DMG installer..."

# Check if app bundle exists
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "❌ App bundle not found. Please run ./Scripts/create-app.sh first."
    exit 1
fi

# Check for required tools
if ! command -v create-dmg &> /dev/null; then
    echo "❌ create-dmg not found. Install with: brew install create-dmg"
    exit 1
fi

# Create staging directory
STAGING_DIR=$(mktemp -d)
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

# Remove existing DMG
rm -f "dist/${DMG_NAME}"

# Create DMG
create-dmg \
  --volname "${VOLUME_NAME}" \
  --volicon "Resources/AppIcon.icns" \
  --background "images/dmg_background.png" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "${APP_BUNDLE}" 170 190 \
  --hide-extension "${APP_BUNDLE}" \
  --app-drop-link 490 190 \
  "dist/${DMG_NAME}" \
  "${STAGING_DIR}"

# Clean up staging directory
rm -rf "${STAGING_DIR}"

# Set custom icon on DMG file
if command -v fileicon &> /dev/null; then
    fileicon set "dist/${DMG_NAME}" "Resources/AppIcon.icns"
    echo "✓ Custom icon set on DMG file"
fi

echo ""
echo "✅ DMG created successfully: dist/${DMG_NAME}"
echo ""
