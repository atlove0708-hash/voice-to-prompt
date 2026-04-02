#!/bin/bash
set -e

# ╔════════════════════════════════════════════════════╗
# ║  Voice to Prompt - ワンコマンドインストーラー       ║
# ║                                                    ║
# ║  使い方:                                           ║
# ║    curl -fsSL URL | bash                           ║
# ╚════════════════════════════════════════════════════╝

G='\033[0;32m' C='\033[0;36m' Y='\033[1;33m' R='\033[0;31m' B='\033[1m' D='\033[2m' N='\033[0m'
REPO="kobayashitakuro/voice-to-prompt"
INSTALL_DIR="$HOME/.local/share/voice-to-prompt"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/Applications/VoiceToPrompt.app"
TMP_DIR=$(mktemp -d)

trap "rm -rf $TMP_DIR" EXIT

echo ""
echo -e "${B}  ╔══════════════════════════════════════╗${N}"
echo -e "${B}  ║     Voice to Prompt  v5.0            ║${N}"
echo -e "${B}  ║   話すだけでプロンプト生成 (無料)     ║${N}"
echo -e "${B}  ╚══════════════════════════════════════╝${N}"
echo ""

# --- 環境チェック ---
echo -e "  ${C}[1/5] 環境チェック${N}"
[[ "$(uname)" != "Darwin" ]] && echo -e "  ${R}✗ macOS専用です${N}" && exit 1
echo -e "  ${D}  macOS $(sw_vers -productVersion)${N}"

if ! command -v swiftc &>/dev/null; then
    echo -e "  ${Y}  Xcode Command Line Tools が必要です${N}"
    echo -e "  ${Y}  インストール中... (数分かかります)${N}"
    xcode-select --install 2>/dev/null || true
    echo -e "  ${Y}  インストール完了後にもう一度実行してください${N}"
    exit 1
fi
echo -e "  ${G}✓ OK${N}"
echo ""

# --- ダウンロード ---
echo -e "  ${C}[2/5] ダウンロード${N}"
if command -v git &>/dev/null; then
    git clone --depth 1 "https://github.com/$REPO.git" "$TMP_DIR/repo" 2>/dev/null
    echo -e "  ${D}  git clone 完了${N}"
else
    curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" | tar xz -C "$TMP_DIR"
    mv "$TMP_DIR"/voice-to-prompt-* "$TMP_DIR/repo"
    echo -e "  ${D}  ダウンロード完了${N}"
fi
echo -e "  ${G}✓ OK${N}"
echo ""

# --- コンパイル ---
echo -e "  ${C}[3/5] コンパイル中... (初回は30秒ほどかかります)${N}"
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

cp -r "$TMP_DIR/repo/Sources" "$INSTALL_DIR/"
cp -r "$TMP_DIR/repo/Resources" "$INSTALL_DIR/"
[ -f "$TMP_DIR/repo/system_prompt.txt" ] && cp "$TMP_DIR/repo/system_prompt.txt" "$INSTALL_DIR/"
[ -f "$TMP_DIR/repo/voice-input-cli.swift" ] && cp "$TMP_DIR/repo/voice-input-cli.swift" "$INSTALL_DIR/"

SOURCES=$(find "$INSTALL_DIR/Sources/VoiceToPrompt" -name "*.swift" | sort)
swiftc -O \
    -framework Cocoa -framework Carbon -framework Speech -framework AVFoundation \
    -module-name VoiceToPrompt \
    $SOURCES \
    -o "$INSTALL_DIR/VoiceToPrompt" 2>/dev/null

if [ -f "$INSTALL_DIR/voice-input-cli.swift" ]; then
    swiftc -O -framework Speech -framework AVFoundation \
        "$INSTALL_DIR/voice-input-cli.swift" \
        -o "$INSTALL_DIR/voice-input-cli" 2>/dev/null
fi

echo -e "  ${G}✓ コンパイル完了${N}"
echo ""

# --- アプリ作成 ---
echo -e "  ${C}[4/5] アプリ作成${N}"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$INSTALL_DIR/VoiceToPrompt" "$APP_DIR/Contents/MacOS/VoiceToPrompt"
[ -f "$INSTALL_DIR/system_prompt.txt" ] && cp "$INSTALL_DIR/system_prompt.txt" "$APP_DIR/Contents/Resources/"
[ -f "$INSTALL_DIR/Resources/system_prompt.txt" ] && cp "$INSTALL_DIR/Resources/system_prompt.txt" "$APP_DIR/Contents/Resources/"

cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>VoiceToPrompt</string>
    <key>CFBundleIdentifier</key><string>com.voicetoprompt.launcher</string>
    <key>CFBundleName</key><string>VoiceToPrompt</string>
    <key>CFBundleDisplayName</key><string>Voice to Prompt</string>
    <key>CFBundleVersion</key><string>5.0.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>音声入力のためにマイクを使用します</string>
    <key>NSSpeechRecognitionUsageDescription</key><string>音声をテキストに変換するために使用します</string>
</dict>
</plist>
PLIST

xattr -cr "$APP_DIR" 2>/dev/null
codesign -s - -f "$APP_DIR" 2>/dev/null

# vp コマンド
cat > "$BIN_DIR/vp" << 'VPSCRIPT'
#!/bin/bash
DIR="$HOME/.local/share/voice-to-prompt"
ENV="$DIR/.env"
KEY=""
[ -f "$ENV" ] && KEY=$(grep "GEMINI_API_KEY=" "$ENV" 2>/dev/null | head -1 | cut -d= -f2 | xargs)
if [ -z "$KEY" ] || [ ${#KEY} -lt 10 ]; then
    echo ""
    echo -e "\033[1;33m  APIキーが未設定です（無料）\033[0m"
    read -p "  Enter で取得ページを開きます..." d
    open "https://aistudio.google.com/apikey" 2>/dev/null
    echo -e "  \033[1mキーをコピーして貼り付け:\033[0m"
    while true; do
        read -p "  APIキー: " k
        k=$(echo "$k" | xargs)
        [ -n "$k" ] && [ ${#k} -ge 10 ] && break
        echo -e "  \033[0;31m正しいキーを入力\033[0m"
    done
    echo "GEMINI_API_KEY=$k" > "$ENV"
    echo -e "\n  \033[0;32m✅ 保存しました\033[0m\n"
fi
echo -e "\n  \033[1mVoice to Prompt\033[0m"
echo -e "  \033[0;36m話し終わったら Enter\033[0m\n"
echo -e "\033[0;32m  🎤 録音中...\033[0m"
T=$("$DIR/voice-input-cli" 2>/dev/tty)
[ -z "$T" ] && echo -e "\033[1;33m  音声なし\033[0m" && exit 1
echo -e "\n  📝 $T\n  ✨ 変換中..."
AK=$(grep "GEMINI_API_KEY=" "$ENV" | cut -d= -f2)
SP=$(cat "$DIR/system_prompt.txt" 2>/dev/null || cat "$DIR/Resources/system_prompt.txt" 2>/dev/null || echo "音声テキストをプロンプトに整えてください。")
B=$(python3 -c "import json,sys;print(json.dumps({'system_instruction':{'parts':[{'text':sys.argv[1]}]},'contents':[{'parts':[{'text':'以下の音声テキストを最適なプロンプトに変換してください:\n\n'+sys.argv[2]}]}],'generationConfig':{'maxOutputTokens':2000,'temperature':0.2}},ensure_ascii=False))" "$SP" "$T" 2>/dev/null)
P=""
for M in gemini-2.5-flash-lite gemini-2.0-flash-lite gemini-2.5-flash; do
    R=$(curl -s --max-time 10 "https://generativelanguage.googleapis.com/v1beta/models/$M:generateContent?key=$AK" -H "Content-Type: application/json" -d "$B" 2>/dev/null)
    P=$(echo "$R" | python3 -c "import sys,json;d=json.loads(sys.stdin.read());print(d.get('candidates',[{}])[0].get('content',{}).get('parts',[{}])[0].get('text',''))" 2>/dev/null)
    [ -n "$P" ] && break; sleep 2
done
echo ""
if [ -n "$P" ]; then
    echo "$P" | pbcopy
    echo -e "  \033[0;32m✅ クリップボードにコピー！\033[0m"
    echo -e "  ┌───────────────────────────"
    echo "$P" | sed 's/^/  │ /'
    echo -e "  └───────────────────────────"
    echo -e "  \033[0;36mCmd+V で貼り付け\033[0m"
else
    echo "$T" | pbcopy
    echo -e "  \033[1;33m⚠️ 元テキストをコピー\033[0m"
fi
echo ""
VPSCRIPT
chmod +x "$BIN_DIR/vp"

# vp-history / vp-view
for cmd in vp-history vp-view; do
    [ -f "$TMP_DIR/repo/$cmd" ] && cp "$TMP_DIR/repo/$cmd" "$BIN_DIR/$cmd" && chmod +x "$BIN_DIR/$cmd"
done

# PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "$BIN_DIR"; then
    RC="$HOME/.zshrc"; [ ! -f "$RC" ] && RC="$HOME/.bashrc"
    grep -q '.local/bin' "$RC" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"
fi

# ログイン項目
osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP_DIR\", hidden:true}" 2>/dev/null || true

echo -e "  ${G}✓ アプリ作成完了${N}"
echo ""

# --- APIキー ---
echo -e "  ${C}[5/5] APIキー設定${N}"
ENV_FILE="$INSTALL_DIR/.env"
[ -f "$ENV_FILE" ] && EXISTING=$(grep "GEMINI_API_KEY=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2 | xargs)

if [ -z "$EXISTING" ] && [ -f "$HOME/Desktop/voice-input/.env" ]; then
    EXISTING=$(grep "GEMINI_API_KEY=" "$HOME/Desktop/voice-input/.env" 2>/dev/null | head -1 | cut -d= -f2 | xargs)
    [ -n "$EXISTING" ] && echo "GEMINI_API_KEY=$EXISTING" > "$ENV_FILE"
fi

if [ -z "$EXISTING" ] || [ ${#EXISTING} -lt 10 ]; then
    echo ""
    echo -e "  ${Y}無料のAPIキーを設定します（1回だけ）${N}"
    echo "  手順: ページが開く → Googleログイン → 「APIキーを作成」→ コピー → ここに貼り付け"
    echo ""
    read -p "  Enter でブラウザを開きます..." dummy
    open "https://aistudio.google.com/apikey" 2>/dev/null
    echo ""
    while true; do
        read -p "  APIキー: " api_key
        api_key=$(echo "$api_key" | xargs)
        [ -n "$api_key" ] && [ ${#api_key} -ge 10 ] && echo "GEMINI_API_KEY=$api_key" > "$ENV_FILE" && echo -e "\n  ${G}✓ 保存しました${N}" && break
        echo -e "  ${R}正しいキーを貼り付けてください${N}"
    done
else
    echo -e "  ${D}  APIキー: 設定済み${N}"
fi

# --- 起動 ---
pkill -f "VoiceToPrompt" 2>/dev/null; sleep 1
open "$APP_DIR"

echo ""
echo -e "  ${G}══════════════════════════════════════${N}"
echo -e "  ${G}  インストール完了！${N}"
echo -e "  ${G}══════════════════════════════════════${N}"
echo ""
echo -e "  ${B}使い方:${N}"
echo -e "    ${B}Shift+Space${N} → 話す → ${B}Shift+Space${N} → ${B}Cmd+V${N}"
echo ""
echo -e "  ${Y}⚠ 最後に1つだけ:${N}"
echo -e "  ${Y}  アクセシビリティの設定画面が開きます${N}"
echo -e "  ${Y}  → VoiceToPrompt を ON にしてください${N}"
echo ""
sleep 2
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null
