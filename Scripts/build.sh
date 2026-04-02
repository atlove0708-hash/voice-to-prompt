#!/bin/bash
set -euo pipefail

# ============================================================
#  VoiceToPrompt ビルド & インストールスクリプト
# ============================================================

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES_DIR="$PROJECT_DIR/Sources/VoiceToPrompt"
RESOURCES_DIR="$PROJECT_DIR/Resources"
APP_NAME="VoiceToPrompt"
APP_DIR="$HOME/Applications/${APP_NAME}.app"
BINARY_NAME="VoiceToPrompt"

echo "=== VoiceToPrompt Build Script ==="
echo "Project: $PROJECT_DIR"

# --- 全ソースファイルを収集 ---
SOURCES=$(find "$SOURCES_DIR" -name "*.swift" | sort)
echo "Sources: $(echo "$SOURCES" | wc -l | tr -d ' ') files"

# --- コンパイル ---
echo "Compiling..."
swiftc -O \
    -framework Cocoa \
    -framework Carbon \
    -framework Speech \
    -framework AVFoundation \
    -module-name VoiceToPrompt \
    $SOURCES \
    -o "$PROJECT_DIR/$BINARY_NAME"

echo "Binary: $PROJECT_DIR/$BINARY_NAME"

# --- .app バンドル作成 ---
echo "Creating app bundle..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$PROJECT_DIR/$BINARY_NAME" "$APP_DIR/Contents/MacOS/$BINARY_NAME"
cp "$RESOURCES_DIR/Info.plist" "$APP_DIR/Contents/"

# system_prompt.txtは実行時に~/Desktop/voice-input/から読む設計のため
# Resourcesには参考用コピーのみ
if [ -f "$RESOURCES_DIR/system_prompt.txt" ]; then
    cp "$RESOURCES_DIR/system_prompt.txt" "$APP_DIR/Contents/Resources/"
fi

# --- 署名 ---
echo "Signing..."
xattr -cr "$APP_DIR"
codesign -s - -f "$APP_DIR"

echo ""
echo "=== Build Complete ==="
echo "App: $APP_DIR"
echo ""
echo "次のステップ:"
echo "  1. pkill VoiceToPrompt 2>/dev/null; open '$APP_DIR'"
echo "  2. システム設定 → アクセシビリティ → VoiceToPrompt ON"
echo "  3. pkill VoiceToPrompt && open '$APP_DIR'"
