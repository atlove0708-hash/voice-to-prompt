#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Voice to Prompt インストーラー
#  このファイルをダブルクリックするだけ！
# ═══════════════════════════════════════════════════════════
set -e

G='\033[0;32m' C='\033[0;36m' Y='\033[1;33m' R='\033[0;31m' B='\033[1m' D='\033[2m' N='\033[0m'
REPO="atlove0708-hash/voice-to-prompt"
INSTALL_DIR="$HOME/.local/share/voice-to-prompt"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/Applications/VoiceToPrompt.app"
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

clear
echo ""
echo ""
echo -e "${B}  ┌─────────────────────────────────────────┐${N}"
echo -e "${B}  │                                         │${N}"
echo -e "${B}  │     🎤 Voice to Prompt                  │${N}"
echo -e "${B}  │                                         │${N}"
echo -e "${B}  │     話すだけでAIプロンプト生成           │${N}"
echo -e "${B}  │     完全無料・3分で使えます              │${N}"
echo -e "${B}  │                                         │${N}"
echo -e "${B}  └─────────────────────────────────────────┘${N}"
echo ""
echo ""

# ═══════════════════════════════════════════════════════════
#  macOSチェック
# ═══════════════════════════════════════════════════════════
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "  ${R}このアプリはMac専用です${N}"
    echo "  Enterで終了"
    read; exit 1
fi

# ═══════════════════════════════════════════════════════════
#  Xcode Command Line Tools（コンパイルに必要）
# ═══════════════════════════════════════════════════════════
if ! command -v swiftc &>/dev/null; then
    echo -e "  ${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    echo -e "  ${Y}  開発ツールをインストールします${N}"
    echo -e "  ${Y}  ポップアップが出たら「インストール」を押してね${N}"
    echo -e "  ${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    echo ""
    xcode-select --install 2>/dev/null || true
    echo ""
    echo -e "  ${B}インストールが終わったら、このファイルをもう一度ダブルクリックしてね！${N}"
    echo ""
    echo "  Enterで閉じる"
    read; exit 0
fi

echo -e "  ${G}✓${N} Mac環境OK"
echo ""

# ═══════════════════════════════════════════════════════════
#  ダウンロード
# ═══════════════════════════════════════════════════════════
echo -e "  ${C}ダウンロード中...${N}"
if command -v git &>/dev/null; then
    git clone --depth 1 "https://github.com/$REPO.git" "$TMP_DIR/repo" 2>/dev/null
else
    curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" | tar xz -C "$TMP_DIR"
    mv "$TMP_DIR"/voice-to-prompt-* "$TMP_DIR/repo"
fi
echo -e "  ${G}✓${N} ダウンロード完了"
echo ""

# ═══════════════════════════════════════════════════════════
#  コンパイル
# ═══════════════════════════════════════════════════════════
echo -e "  ${C}アプリを作成中...（30秒くらいかかります）${N}"
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$HOME/Applications"

cp -r "$TMP_DIR/repo/Sources" "$INSTALL_DIR/"
cp -r "$TMP_DIR/repo/Resources" "$INSTALL_DIR/"
[ -f "$TMP_DIR/repo/system_prompt.txt" ] && cp "$TMP_DIR/repo/system_prompt.txt" "$INSTALL_DIR/"
[ -f "$TMP_DIR/repo/voice-input-cli.swift" ] && cp "$TMP_DIR/repo/voice-input-cli.swift" "$INSTALL_DIR/"

SOURCES=$(find "$INSTALL_DIR/Sources/VoiceToPrompt" -name "*.swift" | sort)

if ! swiftc -O \
    -framework Cocoa -framework Carbon -framework Speech -framework AVFoundation \
    -module-name VoiceToPrompt \
    $SOURCES \
    -o "$INSTALL_DIR/VoiceToPrompt" 2>"$TMP_DIR/build_err.log"; then
    echo ""
    echo -e "  ${R}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    echo -e "  ${R}  コンパイルエラーが発生しました${N}"
    echo -e "  ${R}  macOSを最新版にアップデートしてから${N}"
    echo -e "  ${R}  もう一度試してください${N}"
    echo -e "  ${R}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    cat "$TMP_DIR/build_err.log" 2>/dev/null
    echo "  Enterで閉じる"
    read; exit 1
fi

# CLI版（失敗しても続行）
if [ -f "$INSTALL_DIR/voice-input-cli.swift" ]; then
    swiftc -O -framework Speech -framework AVFoundation \
        "$INSTALL_DIR/voice-input-cli.swift" \
        -o "$INSTALL_DIR/voice-input-cli" 2>/dev/null || true
fi

echo -e "  ${G}✓${N} アプリ作成完了"
echo ""

# ═══════════════════════════════════════════════════════════
#  .appバンドル作成
# ═══════════════════════════════════════════════════════════
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

# --- コマンドツール ---
cat > "$BIN_DIR/vp" << 'VPSCRIPT'
#!/bin/bash
DIR="$HOME/.local/share/voice-to-prompt"
ENV="$DIR/.env"
KEY=""
[ -f "$ENV" ] && KEY=$(grep "GEMINI_API_KEY=" "$ENV" 2>/dev/null | head -1 | cut -d= -f2 | xargs)
if [ -z "$KEY" ] || [ ${#KEY} -lt 10 ]; then
    echo -e "\n\033[1;33m  APIキーが未設定です（無料）\033[0m"
    read -p "  Enter で取得ページを開きます..." d
    open "https://aistudio.google.com/apikey" 2>/dev/null
    while true; do
        read -p "  APIキー: " k
        k=$(echo "$k" | xargs)
        [ -n "$k" ] && [ ${#k} -ge 10 ] && break
        echo -e "  \033[0;31m正しいキーを入力\033[0m"
    done
    echo "GEMINI_API_KEY=$k" > "$ENV"
    echo -e "\n  \033[0;32m✅ 保存しました\033[0m\n"
fi
echo -e "\n  \033[1mVoice to Prompt\033[0m  \033[0;36m話し終わったら Enter\033[0m\n\033[0;32m  🎤 録音中...\033[0m"
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
if [ -n "$P" ]; then echo "$P" | pbcopy; echo -e "  \033[0;32m✅ コピー済\033[0m\n  ┌───────────────"; echo "$P" | sed 's/^/  │ /'; echo -e "  └───────────────\n  \033[0;36mCmd+V で貼り付け\033[0m"
else echo "$T" | pbcopy; echo -e "  \033[1;33m⚠️ 元テキストをコピー\033[0m"; fi
echo ""
VPSCRIPT
chmod +x "$BIN_DIR/vp"

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

echo -e "  ${G}✓${N} インストール完了"
echo ""

# ═══════════════════════════════════════════════════════════
#  APIキー設定（対話式・超丁寧ガイド）
# ═══════════════════════════════════════════════════════════
ENV_FILE="$INSTALL_DIR/.env"
EXISTING=""
[ -f "$ENV_FILE" ] && EXISTING=$(grep "GEMINI_API_KEY=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2 | xargs)
[ -z "$EXISTING" ] && [ -f "$HOME/Desktop/voice-input/.env" ] && {
    EXISTING=$(grep "GEMINI_API_KEY=" "$HOME/Desktop/voice-input/.env" 2>/dev/null | head -1 | cut -d= -f2 | xargs)
    [ -n "$EXISTING" ] && echo "GEMINI_API_KEY=$EXISTING" > "$ENV_FILE"
}

if [ -z "$EXISTING" ] || [ ${#EXISTING} -lt 10 ]; then
    echo ""
    echo -e "  ${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    echo -e "  ${B}  APIキーの設定（無料・1回だけ）${N}"
    echo -e "  ${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    echo ""
    echo -e "  今からブラウザが開きます。"
    echo ""
    echo -e "  ${C}やること:${N}"
    echo -e "  ${B}  1.${N} Googleでログイン"
    echo -e "  ${B}  2.${N}「APIキーを作成」ボタンを押す"
    echo -e "  ${B}  3.${N} 表示されたキーをコピー"
    echo -e "  ${B}  4.${N} ここに戻って貼り付け"
    echo ""
    read -p "  Enterでブラウザを開く → " dummy
    open "https://aistudio.google.com/apikey" 2>/dev/null
    echo ""
    echo -e "  ${B}キーをコピーしたら、ここに貼り付けてEnter:${N}"
    echo ""
    while true; do
        read -p "  APIキー: " api_key
        api_key=$(echo "$api_key" | xargs)
        if [ -n "$api_key" ] && [ ${#api_key} -ge 10 ]; then
            # APIキーの動作確認
            echo ""
            echo -e "  キーを確認中..."
            TEST_RESULT=$(curl -s --max-time 10 \
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$api_key" \
                -H "Content-Type: application/json" \
                -d '{"contents":[{"parts":[{"text":"OK"}]}]}' 2>/dev/null)
            if echo "$TEST_RESULT" | python3 -c "import sys,json;d=json.loads(sys.stdin.read());print(d['candidates'][0]['content']['parts'][0]['text'])" &>/dev/null; then
                echo "GEMINI_API_KEY=$api_key" > "$ENV_FILE"
                echo -e "  ${G}✓ APIキー確認OK！保存しました${N}"
                break
            else
                echo -e "  ${R}このキーは使えないようです。もう一度コピーして貼り付けてください${N}"
            fi
        else
            echo -e "  ${R}キーが短すぎます。もう一度コピーして貼り付けてください${N}"
        fi
    done
else
    echo -e "  ${G}✓${N} APIキー設定済み"
fi

echo ""

# ═══════════════════════════════════════════════════════════
#  起動 & アクセシビリティ許可
# ═══════════════════════════════════════════════════════════
pkill -f "VoiceToPrompt" 2>/dev/null; sleep 1
open "$APP_DIR"

echo ""
echo -e "  ${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "  ${B}  あと1つだけ！（これで最後）${N}"
echo -e "  ${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo ""
echo -e "  今から設定画面が開きます。"
echo ""
echo -e "  ${C}やること:${N}"
echo -e "  ${B}  1.${N} リストから ${B}VoiceToPrompt${N} を探す"
echo -e "  ${B}  2.${N} スイッチを ${G}ON（青色）${N} にする"
echo -e "  ${B}  3.${N} パスワードを聞かれたらMacのパスワードを入力"
echo ""
read -p "  Enterで設定画面を開く → " dummy
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null

echo ""
echo -e "  ${B}ONにしたらEnterを押してね${N}"
read -p "  → " dummy

# アプリ再起動
pkill -f "VoiceToPrompt" 2>/dev/null; sleep 1
open "$APP_DIR"

echo ""
echo ""
echo -e "  ${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "  ${G}                                         ${N}"
echo -e "  ${G}  🎉 セットアップ完了！                   ${N}"
echo -e "  ${G}                                         ${N}"
echo -e "  ${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo ""
echo -e "  ${B}使い方:${N}"
echo ""
echo -e "    ${C}Shift+Space${N}  →  話す  →  ${C}Shift+Space${N}  →  ${C}Cmd+V${N}"
echo ""
echo -e "  メニューバーに 🎤 が出てればOK！"
echo -e "  Macを再起動しても自動で起動します。"
echo ""
echo ""
echo "  Enterで閉じる"
read
