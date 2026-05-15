#!/bin/bash
# Build SmartEnglish.pkg installer
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="SmartEnglish"
VERSION="0.2.1"
BUILD_DIR="$PROJECT_DIR/build/pkg"
DIST_DIR="$PROJECT_DIR/dist"

# Find built .app
DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData -name "${APP_NAME}-*" -type d -maxdepth 1 2>/dev/null | head -1)
APP_PATH="${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: ${APP_NAME}.app not found. Run 'make build' first."
    exit 1
fi

echo "Building ${APP_NAME} installer..."

# Clean and create directories
rm -rf "$BUILD_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$BUILD_DIR/scripts"
mkdir -p "$DIST_DIR"

# Copy .app to scripts directory (will be installed by postinstall)
cp -R "$APP_PATH" "$BUILD_DIR/scripts/"

# Create postinstall script that handles the actual installation
cat > "$BUILD_DIR/scripts/postinstall" << 'POSTINSTALL'
#!/bin/bash
# Post-installation script for SmartEnglish
set -e

APP_NAME="SmartEnglish"
INSTALL_DIR="$HOME/Library/Input Methods"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Create directory if needed
mkdir -p "$INSTALL_DIR"

# Remove old installation
rm -rf "$INSTALL_DIR/$APP_NAME.app"

# Copy app from scripts directory to Input Methods
cp -R "$SCRIPT_DIR/$APP_NAME.app" "$INSTALL_DIR/"

# Remove quarantine attribute
xattr -d com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

# Try to add input source programmatically
INPUT_SOURCE="com.songhuiming.inputmethod.SmartEnglish"
ADDED=false

if defaults read com.apple.HIToolbox AppleEnabledInputSources &>/dev/null; then
    if defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null | grep -q "$INPUT_SOURCE"; then
        ADDED=true
    fi
fi

if [ "$ADDED" = false ]; then
    defaults write com.apple.HIToolbox AppleEnabledInputSources -array-add \
        "{ Bundle = $INPUT_SOURCE; InputSourceID = $INPUT_SOURCE; }" 2>/dev/null && ADDED=true || true
fi

# Kill any running instances to force reload
killall SmartEnglishExtension 2>/dev/null || true
killall SmartEnglish 2>/dev/null || true

exit 0
POSTINSTALL

chmod +x "$BUILD_DIR/scripts/postinstall"

# Create a dummy component package (postinstall does the real work)
mkdir -p "$BUILD_DIR/empty"
pkgbuild \
    --root "$BUILD_DIR/empty" \
    --install-location "/tmp/.SmartEnglish-installer" \
    --identifier "com.songhuiming.pkg.SmartEnglish" \
    --version "$VERSION" \
    --scripts "$BUILD_DIR/scripts" \
    "$BUILD_DIR/SmartEnglish-component.pkg"

# Create distribution XML
cat > "$BUILD_DIR/distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>SmartEnglish</title>
    <options customize="never" require-scripts="false" hostArchitectures="x86_64,arm64"/>
    <domains enable_anywhere="false" enable_currentUserHome="true" enable_localSystem="false"/>
    <choices-outline>
        <line choice="default">
            <line choice="com.songhuiming.pkg.SmartEnglish"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.songhuiming.pkg.SmartEnglish" visible="false">
        <pkg-ref id="com.songhuiming.pkg.SmartEnglish"/>
    </choice>
    <pkg-ref id="com.songhuiming.pkg.SmartEnglish" version="${VERSION}" onConclusion="none">SmartEnglish-component.pkg</pkg-ref>
    <welcome file="welcome.html" mime-type="text/html"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>
</installer-gui-script>
EOF

# Create welcome page
cat > "$BUILD_DIR/welcome.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; line-height: 1.6; color: #333; }
        h2 { color: #1a1a1a; margin-bottom: 20px; }
        .feature { margin: 10px 0; padding-left: 20px; }
        .icon { margin-right: 8px; }
    </style>
</head>
<body>
    <h2>Welcome to SmartEnglish Installer</h2>
    <p>SmartEnglish is a smart English input method for macOS with:</p>
    <div class="feature"><span class="icon">📝</span> Intelligent word completion</div>
    <div class="feature"><span class="icon">⚡</span> Fast and responsive</div>
    <div class="feature"><span class="icon">🎯</span> Context-aware suggestions</div>
    <br>
    <p>This will install SmartEnglish to your Input Methods folder and optionally add it to your keyboard inputs.</p>
</body>
</html>
EOF

# Create conclusion page
cat > "$BUILD_DIR/conclusion.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; line-height: 1.6; color: #333; }
        h2 { color: #34c759; margin-bottom: 20px; }
        .step { margin: 15px 0; padding: 12px; background: #f5f5f7; border-radius: 8px; }
        .step-number { display: inline-block; width: 24px; height: 24px; background: #007AFF; color: white; border-radius: 50%; text-align: center; line-height: 24px; margin-right: 8px; font-size: 14px; }
        .shortcut { background: #e8e8ed; padding: 2px 8px; border-radius: 4px; font-family: monospace; }
    </style>
</head>
<body>
    <h2>✓ Installation Complete!</h2>
    <p>To start using SmartEnglish:</p>
    <div class="step">
        <span class="step-number">1</span>
        Open <strong>System Settings → Keyboard → Input Sources</strong>
    </div>
    <div class="step">
        <span class="step-number">2</span>
        Click <strong>+</strong> and select <strong>English → SmartEnglish</strong>
    </div>
    <div class="step">
        <span class="step-number">3</span>
        Press <span class="shortcut">Ctrl + Space</span> to switch input methods
    </div>
    <br>
    <p>You may need to log out and log back in for changes to take effect.</p>
</body>
</html>
EOF

# Build final package
productbuild \
    --distribution "$BUILD_DIR/distribution.xml" \
    --package-path "$BUILD_DIR" \
    --resources "$BUILD_DIR" \
    "$DIST_DIR/SmartEnglish.pkg"

echo ""
echo "✓ Package created: dist/SmartEnglish.pkg"
echo ""

# Clean up build directory
rm -rf "$BUILD_DIR"
