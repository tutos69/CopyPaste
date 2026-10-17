#!/bin/bash
# Builds CopyPaste.app (universal: Apple Silicon + Intel).
#   ./build.sh            -> build/CopyPaste.app
#   ./build.sh --install  -> also copies it to /Applications and launches it
#   ./build.sh --release  -> also creates build/CopyPaste.zip for a GitHub release
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v swiftc >/dev/null; then
    echo "swiftc not found. Install the Command Line Tools with: xcode-select --install" >&2
    exit 1
fi

mkdir -p build

# Workaround for some broken Command Line Tools installs: a stale usr/include/swift/module.modulemap
# next to bridging.modulemap redefines 'SwiftBridging'. Hide it behind an empty file for this build only.
SWIFT_INCLUDE="$(dirname "$(dirname "$(xcrun -f swiftc)")")/include/swift"
OVERLAY_ARGS=()
if [[ -f "$SWIFT_INCLUDE/module.modulemap" && -f "$SWIFT_INCLUDE/bridging.modulemap" ]]; then
    : > build/empty.modulemap
    cat > build/overlay.yaml <<EOF
{ "version": 0, "case-sensitive": "false", "roots": [ { "type": "file", "name": "$SWIFT_INCLUDE/module.modulemap", "external-contents": "$PWD/build/empty.modulemap" } ] }
EOF
    OVERLAY_ARGS=(-vfsoverlay build/overlay.yaml)
fi

for ARCH in arm64 x86_64; do
    swiftc -O "${OVERLAY_ARGS[@]}" -target "$ARCH-apple-macos14.0" \
        -o "build/CopyPaste-$ARCH" Sources/CopyPaste/*.swift
done

APP="build/CopyPaste.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create build/CopyPaste-arm64 build/CopyPaste-x86_64 -output "$APP/Contents/MacOS/CopyPaste"
rm build/CopyPaste-arm64 build/CopyPaste-x86_64
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x CopyPaste || true
    rm -rf /Applications/CopyPaste.app
    cp -R "$APP" /Applications/
    open /Applications/CopyPaste.app
    echo "Installed to /Applications/CopyPaste.app"
fi

if [[ "${1:-}" == "--release" ]]; then
    rm -f build/CopyPaste.zip
    ditto -c -k --keepParent "$APP" build/CopyPaste.zip
    echo "Created build/CopyPaste.zip (upload it to a GitHub release)"
fi
