#!/bin/bash
set -e

echo "Building SmartEnglish..."
xcodebuild -project SmartEnglish.xcodeproj -scheme SmartEnglish -configuration Release build 2>&1 | tail -5

echo "Installing..."
killall SmartEnglishExtension 2>/dev/null || true
killall SmartEnglish 2>/dev/null || true
sleep 0.5
rm -rf ~/Library/Input\ Methods/SmartEnglish.app

BUILD_DIR=$(xcodebuild -project SmartEnglish.xcodeproj -scheme SmartEnglish -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')
cp -R "${BUILD_DIR}/SmartEnglish.app" ~/Library/Input\ Methods/

echo "Done! SmartEnglish installed to ~/Library/Input Methods/"
echo ""
echo "First time install:"
echo "   1. System Settings -> Keyboard -> Input Sources"
echo "   2. Click + to add input source"
echo "   3. Find SmartEnglish under English category"
echo "   4. Switch to SmartEnglish from menu bar"
