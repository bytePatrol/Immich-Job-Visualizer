#!/bin/bash

# Create .app Bundle for Immich Job Queue Visualizer
# This script packages the executable into a proper macOS application

set -e

echo "📦 Creating ImmichJobQueueVisualizer.app bundle..."

# Create the app bundle structure
mkdir -p ImmichJobQueueVisualizer.app/Contents/MacOS
mkdir -p ImmichJobQueueVisualizer.app/Contents/Resources

# Copy the executable
cp .build/release/ImmichJobQueueVisualizer ImmichJobQueueVisualizer.app/Contents/MacOS/

# Copy Info.plist
cp Info.plist ImmichJobQueueVisualizer.app/Contents/

# Make it executable
chmod +x ImmichJobQueueVisualizer.app/Contents/MacOS/ImmichJobQueueVisualizer

echo ""
echo "✅ ImmichJobQueueVisualizer.app created successfully!"
echo ""
echo "You can now:"
echo "  • Double-click ImmichJobQueueVisualizer.app to run"
echo "  • Drag it to /Applications to install"
echo "  • Right-click and Compress to zip and share"
echo ""
