#!/bin/bash

# Build script for Immich Job Queue Visualizer
# This script handles building the macOS application

set -e

# Change to project root (parent of Scripts directory)
cd "$(dirname "$0")/.."

echo "🚀 Building Immich Job Queue Visualizer..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script must be run on macOS${NC}"
    exit 1
fi

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo -e "${RED}Error: Swift is not installed${NC}"
    echo "Please install Xcode from the Mac App Store"
    exit 1
fi

echo -e "${GREEN}✓${NC} Swift found: $(swift --version | head -n 1)"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf .build

# Build the project
echo "🔨 Building project..."
swift build -c release

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build successful!${NC}"
    echo ""
    echo "📦 Executable location: .build/release/ImmichJobQueueVisualizer"
    echo ""
    echo "To run the application:"
    echo "  ./.build/release/ImmichJobQueueVisualizer"
    echo ""
    echo "To create an app bundle, run:"
    echo "  ./Scripts/create-app.sh"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi
