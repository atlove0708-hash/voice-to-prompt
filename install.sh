#!/bin/bash
set -e

# ╔════════════════════════════════════════════════════╗
# ║  Voice to Prompt v5 - インストーラー               ║
# ║  話すだけでAIが最適なプロンプトを生成 (無料)        ║
# ║                                                    ║
# ║  使い方:                                           ║
# ║    git clone → cd voice-to-prompt → bash install.sh║
# ╚════════════════════════════════════════════════════╝

G='\033[0;32m' C='\033[0;36m' Y='\033[1;33m' R='\033[0;31m' B='\033[1m' D='\033[2m' N='\033[0m'

INSTALL_DIR="$HOME/.local/share/voice-to-prompt"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/Applications/VoiceToPrompt.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || pwd)"

echo ""
echo -e "${B}  ╔══════════════════════════════════════╗${N}"
echo -e "${B}  ║     Voice to Prompt  v5.0            ║${N}"
echo -e "${B}  ║   話すだけでプロンプト生成 (無料)     ║${N}"
echo -e "${B}  ╚══════════════════════════════════════╝${N}"
echo ""

# ============================================================
#  環境チェック
# ============================================================
echo -e "  ${C}[1/5] 環境チェック${N}"

if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "  ${R}✗ macOS専用です${N}"; exit 1
fi
echo -e "  ${D}  macOS $(sw_vers -productVersion)${N}"

if ! command -v swiftc &>/dev/null; then
    echo -e "  ${Y}  Xcode Command Line Tools をインストールします...${N}"
    xcode-select --install 2>/dev/null || true
    echo -e "  ${Y}  インストール完了後にもう一度 bash install.sh を実行してください${N}"
    exit 1
fi
echo -e "  ${D}  Swift $(swiftc --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)${N}"

if ! command -v python3 &>/dev/null; then
    echo -e "  ${R}✗ Python3が必要です${N}"; exit 1
fi

command -v curl &>/dev/null || { echo -e "  ${R}✗ curlが必要です${N}"; exit 1; }
echo -e "  ${G}✓ 環境OK${N}"
echo ""

# ============================================================
#  ソースファイル配置
# ============================================================
echo -e "  ${C}[2/5] ファイル配置${N}"
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# v5モジュラー構成のソースをコピー
if [ -d "$SCRIPT_DIR/Sources" ]; then
    cp -r "$SCRIPT_DIR/Sources" "$INSTALL_DIR/"
    cp -r "$SCRIPT_DIR/Resources" "$INSTALL_DIR/"
    [ -f "$SCRIPT_DIR/system_prompt.txt" ] && cp "$SCRIPT_DIR/system_prompt.txt" "$INSTALL_DIR/"
    [ -f "$SCRIPT_DIR/voice-input-cli.swift" ] && cp "$SCRIPT_DIR/voice-input-cli.swift" "$INSTALL_DIR/"
    echo -e "  ${D}  ソースファイルをコピー${N}"
else
    echo -e "  ${R}✗ Sourcesフォルダが見つかりません。リポジトリからcloneしてください。${N}"
    exit 1
fi

echo -e "  ${G}✓ 配置完了${N}"
echo ""

# ============================================================
#  コンパイル
# ============================================================
echo -e "  ${C}[3/5] コンパイル中...${N}"

# v5: モジュラー構成 - 全Swiftファイルを一括コンパイル
SOURCES=$(find "$INSTALL_DIR/Sources/VoiceToPrompt" -name "*.swift" | sort)
SOURCE_COUNT=$(echo "$SOURCES" | wc -l | tr -d ' ')
echo -e "  ${D}  $SOURCE_COUNT ファイルをコンパイル中...${N}"

swiftc -O \
    -framework Cocoa -framework Carbon -framework Speech -framework AVFoundation \
    -module-name VoiceToPrompt \
    $SOURCES \
    -o "$INSTALL_DIR/VoiceToPrompt" 2>/dev/null

echo -e "  ${D}  ✓ VoiceToPrompt (メインアプリ)${N}"

# CLI版
if [ -f "$INSTALL_DIR/voice-input-cli.swift" ]; then
    swiftc -O -framework Speech -framework AVFoundation \
        "$INSTALL_DIR/voice-input-cli.swift" \
        -o "$INSTALL_DIR/voice-input-cli" 2>/dev/null
    echo -e "  ${D}  ✓ voice-input-cli (ターミナル用)${N}"
fi

echo -e "  ${G}✓ コンパイル完了${N}"
echo ""

# ============================================================
#  .app バンドル作成
# ============================================================
echo -e "  ${C}[4/5] アプリ作成${N}"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$INSTALL_DIR/VoiceToPrompt" "$APP_DIR/Contents/MacOS/VoiceToPrompt"

# system_prompt.txtをResourcesにもコピー
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
    <key>CFBundleShortVersionString</key><string>5.0.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>音声入力のためにマイクを使用します</string>
    <key>NSSpeechRecognitionUsageDescription</key><string>音声をテキストに変換するために音声認識を使用します</string>
</dict>
</plist>
PLIST

xattr -cr "$APP_DIR" 2>/dev/null
codesign -s - -f "$APP_DIR" 2>/dev/null

# --- vp コマンド ---
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
    open "https://aistudio.google.com/apikey" 2>/dev/null || echo "  https://aistudio.google.com/apikey を開いてください"
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

# --- vp-history / vp-view ---
for cmd in vp-history vp-view; do
    if [ -f "$SCRIPT_DIR/$cmd" ]; then
        cp "$SCRIPT_DIR/$cmd" "$BIN_DIR/$cmd"
        chmod +x "$BIN_DIR/$cmd"
    fi
done

# --- デスクトップショートカット ---
cat > "$HOME/Desktop/Voice to Prompt.command" << 'LAUNCHER'
#!/bin/bash
exec "$HOME/.local/bin/vp"
LAUNCHER
chmod +x "$HOME/Desktop/Voice to Prompt.command"

# --- PATH追加 ---
if ! echo "$PATH" | tr ':' '\n' | grep -q "$BIN_DIR"; then
    RC="$HOME/.zshrc"
    [ ! -f "$RC" ] && RC="$HOME/.bashrc"
    if ! grep -q '.local/bin' "$RC" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"
    fi
fi

# --- ログイン項目に追加 ---
osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP_DIR\", hidden:true}" 2>/dev/null || true

echo -e "  ${G}✓ アプリ作成完了${N}"
echo ""

# ============================================================
#  APIキー設定
# ============================================================
echo -e "  ${C}[5/5] APIキー設定${N}"

ENV_FILE="$INSTALL_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    EXISTING=$(grep "GEMINI_API_KEY=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2 | xargs)
fi

# 元の場所の.envもチェック
if [ -z "$EXISTING" ] && [ -f "$HOME/Desktop/voice-input/.env" ]; then
    EXISTING=$(grep "GEMINI_API_KEY=" "$HOME/Desktop/voice-input/.env" 2>/dev/null | head -1 | cut -d= -f2 | xargs)
    if [ -n "$EXISTING" ]; then
        echo "GEMINI_API_KEY=$EXISTING" > "$ENV_FILE"
        echo -e "  ${D}  既存のAPIキーを移行しました${N}"
    fi
fi

if [ -z "$EXISTING" ] || [ ${#EXISTING} -lt 10 ]; then
    echo ""
    echo -e "  ${Y}無料のAPIキーを設定します（1回だけ）${N}"
    echo ""
    echo "  手順:"
    echo "    1. 次のページでGoogleにログイン"
    echo "    2.「APIキーを作成」を押す"
    echo "    3. キーをコピーしてここに貼り付け"
    echo ""
    read -p "  Enter でブラウザを開きます..." dummy
    open "https://aistudio.google.com/apikey" 2>/dev/null || echo "  https://aistudio.google.com/apikey を開いてください"
    echo ""
    while true; do
        read -p "  APIキー: " api_key
        api_key=$(echo "$api_key" | xargs)
        if [ -n "$api_key" ] && [ ${#api_key} -ge 10 ]; then
            echo "GEMINI_API_KEY=$api_key" > "$ENV_FILE"
            echo -e "\n  ${G}✓ 保存しました${N}"
            break
        fi
        echo -e "  ${R}正しいキーを貼り付けてください${N}"
    done
else
    echo -e "  ${D}  APIキー: 設定済み (${EXISTING:0:10}...)${N}"
fi

echo ""

# ============================================================
#  アプリ起動
# ============================================================
pkill -f "VoiceToPrompt" 2>/dev/null
sleep 1
open "$APP_DIR"

echo -e "  ${G}══════════════════════════════════════${N}"
echo -e "  ${G}  インストール完了！${N}"
echo -e "  ${G}══════════════════════════════════════${N}"
echo ""
echo -e "  ${B}使い方 (2通り):${N}"
echo ""
echo -e "  ${C}● ショートカットキー (おすすめ)${N}"
echo -e "    ${B}Shift+Space${N} → 話す → ${B}Shift+Space${N} → ${B}Cmd+V${N}"
echo ""
echo -e "  ${C}● ターミナルから${N}"
echo -e "    ${B}vp${N} → 話す → ${B}Enter${N} → ${B}Cmd+V${N}"
echo ""
echo -e "  ${D}メニューバーに 🎤 が常駐します${N}"
echo -e "  ${D}Mac再起動後も自動で起動します${N}"
echo ""

# アクセシビリティ設定を開く
echo -e "  ${Y}⚠ アクセシビリティの設定画面を開きます${N}"
echo -e "  ${Y}  VoiceToPrompt を ON にしてください${N}"
echo ""
sleep 2
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null
