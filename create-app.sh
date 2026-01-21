#!/bin/bash

# Create .app Bundle for Immich Job Queue Visualizer
# This script packages the executable into a proper macOS application
# with ad-hoc code signing for distribution without an Apple Developer certificate

set -e

APP_NAME="ImmichJobQueueVisualizer"
APP_BUNDLE="${APP_NAME}.app"
EXECUTABLE_NAME="ImmichJobQueueVisualizer"
BUNDLE_ID="com.immich.queuevisualizer"

echo "📦 Creating ${APP_BUNDLE} bundle..."

# Clean up any existing app bundle
rm -rf "${APP_BUNDLE}"

# Create the app bundle structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy the executable
cp ".build/release/${EXECUTABLE_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Make it executable
chmod +x "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"

# Create a processed Info.plist (replace Xcode variables with actual values)
echo "📝 Creating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Immich Queue Visualizer</string>
    <key>CFBundleExecutable</key>
    <string>ImmichJobQueueVisualizer</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.immich.queuevisualizer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Immich Queue Visualizer</string>
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
</dict>
</plist>
EOF

# Ad-hoc code signing
# Using '-' as identity means ad-hoc signing (no Apple Developer certificate required)
# This creates a valid code signature that satisfies basic Gatekeeper checks
echo "🔏 Applying ad-hoc code signature..."

# Sign the app bundle with ad-hoc identity
# --force: Replace any existing signature
# --deep: Sign nested code (frameworks, plugins, etc.)
# --options runtime is NOT used because it requires a valid Developer ID for notarization
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
echo "  • Compress to zip for distribution"
echo ""
