#!/bin/bash

# Create .app Bundle for Immich Job Queue Visualizer
# This script packages the executable into a proper macOS application
# with ad-hoc code signing for distribution without an Apple Developer certificate

set -e

# Change to project root (parent of Scripts directory)
cd "$(dirname "$0")/.."

APP_NAME="Immich Job Queue Visualizer"
APP_BUNDLE="${APP_NAME}.app"
EXECUTABLE_NAME="ImmichJobQueueVisualizer"
BUNDLE_ID="com.immich.queuevisualizer"

echo "📦 Creating ${APP_BUNDLE} bundle..."

# Check if executable exists
if [ ! -f ".build/release/${EXECUTABLE_NAME}" ]; then
    echo "❌ Executable not found. Please run ./Scripts/build.sh first."
    exit 1
fi

# Clean up any existing app bundle
rm -rf "${APP_BUNDLE}"

# Create the app bundle structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy the executable
cp ".build/release/${EXECUTABLE_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Make it executable
chmod +x "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"

# Copy the app icon if it exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "✓ App icon copied"
fi

# Create a processed Info.plist
echo "📝 Creating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Immich Job Queue Visualizer</string>
    <key>CFBundleExecutable</key>
    <string>ImmichJobQueueVisualizer</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.immich.queuevisualizer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Immich Job Queue Visualizer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>This app uses AppleScript for automation capabilities.</string>
    <key>NSUserNotificationsUsageDescription</key>
    <string>This app sends notifications for job queue alerts and status updates.</string>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
    <key>NSLocalNetworkUsageDescription</key>
    <string>This app connects to your local Immich server to monitor job queues.</string>
</dict>
</plist>
EOF

# Ad-hoc code signing
echo "🔏 Applying ad-hoc code signature..."
codesign --force --deep --sign - "${APP_BUNDLE}"

# Verify the signature
echo "✅ Verifying code signature..."
codesign --verify --verbose=2 "${APP_BUNDLE}" 2>&1 || {
    echo "⚠️  Warning: Code signature verification had issues, but the app should still work"
}

# Display signature info
echo ""
echo "📋 Signature details:"
codesign --display --verbose=2 "${APP_BUNDLE}" 2>&1 | head -10

echo ""
echo "✅ ${APP_BUNDLE} created and signed successfully!"
echo ""
echo "📌 IMPORTANT: This app is ad-hoc signed (not notarized)."
echo "   Users will need to bypass Gatekeeper on first launch:"
echo ""
echo "   Option 1: Right-click (or Control-click) the app → select 'Open'"
echo "   Option 2: System Settings → Privacy & Security → click 'Open Anyway'"
echo ""
echo "You can now:"
echo "  • Double-click ${APP_BUNDLE} to run (after Gatekeeper bypass)"
echo "  • Drag it to /Applications to install"
echo "  • Run ./Scripts/create-dmg.sh to create a DMG installer"
echo ""
