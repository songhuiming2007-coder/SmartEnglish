#!/bin/bash
# SmartEnglish Installer — double-click to install
set -e

APP_NAME="SmartEnglish"
INSTALL_DIR="$HOME/Library/Input Methods"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║     SmartEnglish Installer v0.2.0    ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# 1. Kill running instances
echo "  Stopping running instances..."
killall SmartEnglish 2>/dev/null || true
killall SmartEnglishExtension 2>/dev/null || true
sleep 0.3

# 2. Copy app to Input Methods
echo "  Installing to ~/Library/Input Methods/..."
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$SCRIPT_DIR/$APP_NAME.app" "$INSTALL_DIR/"

# 3. Remove quarantine attribute
xattr -d com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

echo -e "  ${GREEN}✓${NC} $APP_NAME.app installed"

# 4. Try to add input source programmatically
INPUT_SOURCE="com.songhuiming.inputmethod.SmartEnglish"
ADDED=false

if defaults read com.apple.HIToolbox AppleEnabledInputSources &>/dev/null; then
    # Check if already added
    if defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null | grep -q "$INPUT_SOURCE"; then
        ADDED=true
    fi
fi

if [ "$ADDED" = false ]; then
    # Try to add via defaults
    defaults write com.apple.HIToolbox AppleEnabledInputSources -array-add \
        "{ Bundle = $INPUT_SOURCE; InputSourceID = $INPUT_SOURCE; }" 2>/dev/null && ADDED=true || true
fi

if [ "$ADDED" = true ]; then
    echo -e "  ${GREEN}✓${NC} Input source added"
else
    echo -e "  ${YELLOW}!${NC} Could not auto-add input source"
    echo ""
    echo "  Please add manually:"
    echo "  System Settings → Keyboard → Input Sources → + → English → SmartEnglish"
    echo ""
    # Open System Settings to the right pane
    open "x-apple.systempreferences:com.apple.preference.keyboard?InputSources" 2>/dev/null || true
fi

# 5. Done
echo ""
echo -e "  ${GREEN}════════════════════════════════════════${NC}"
echo -e "  ${GREEN}  Installation complete!${NC}"
echo -e "  ${GREEN}════════════════════════════════════════${NC}"
echo ""
echo "  Switch to SmartEnglish:"
echo "    • Press Ctrl+Space to cycle input sources"
echo "    • Or click the input icon in the menu bar"
echo ""
echo "  To uninstall later:"
echo "    rm -rf ~/Library/Input\\ Methods/SmartEnglish.app"
echo ""
read -n 1 -s -r -p "  Press any key to close..."
echo ""
