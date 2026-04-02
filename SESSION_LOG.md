# Voice to Prompt - セッションログ

> 新しいセッションでこのファイルを読み込ませれば、プロジェクトの全コンテキストを即座に復元できます。
> 使い方: 新しいClaudeセッションで「`cat ~/Desktop/voice-input/SESSION_LOG.md` の内容を読んで、このプロジェクトの続きを手伝ってください」と伝えてください。

---

## プロジェクト概要

**Voice to Prompt** - macOSで `Shift+Space` を押すだけで音声入力 → AIがプロンプトに変換 → クリップボードにコピーするネイティブアプリ。

**目的**: 言語化が苦手な人でも、話すだけでAIに渡す最適な指示文（プロンプト）を生成できるツール。

---

## アーキテクチャ

```
[Shift+Space] → macOS Speech Framework (オフライン音声認識)
                    ↓
              テキスト (日本語)
                    ↓
              Gemini API (無料、gemini-2.5-flash-lite)
              ・音声認識の誤変換修正
              ・意図を汲み取って補完
              ・プロンプトとして整形
                    ↓
              クリップボードにコピー → [Cmd+V] で貼り付け
```

**技術スタック**: Swift (macOS native), Carbon API (ホットキー), Speech Framework, Gemini REST API, Bash

---

## ファイル構成

### 動作用 (`~/Desktop/voice-input/`)
```
.env                    ← GEMINI_API_KEY=AIzaSy... (gitignore対象)
HotkeyLauncher.swift    ← メインアプリソース (422行)
HotkeyLauncher          ← コンパイル済みバイナリ
system_prompt.txt       ← AIのシステムプロンプト (外部ファイル化、再ビルド不要で変更可)
voice-input-cli.swift   ← ターミナル用音声入力CLIソース
voice-input-cli         ← コンパイル済みCLIバイナリ
vp                      ← ターミナル用vpコマンドスクリプト
history/
  voice_history.jsonl   ← 全履歴 (JSON Lines)
  index.html            ← ブラウザ用履歴ビューア (vp-viewで生成)
  dates/
    2026-04-01/          ← 日付別フォルダに個別JSON保存
    2026-04-02/
```

### インストール済みアプリ (`~/Applications/VoiceToPrompt.app`)
```
Contents/
  MacOS/VoiceToPrompt   ← HotkeyLauncherのコピー
  Info.plist            ← バンドルID: com.voicetoprompt.launcher, LSUIElement=true
```

### コマンド (`~/.local/bin/`)
```
vp          → ~/Desktop/voice-input/vp へのシンボリックリンク (ターミナル用)
vp-history  ← 履歴検索・復元CLIツール
vp-view     ← 履歴HTMLビューア生成・表示
```

### 配布用リポジトリ (`~/Desktop/voice-to-prompt/`)
```
.git/                   ← git初期化済み (3コミット)
HotkeyLauncher.swift
voice-input-cli.swift
system_prompt.txt
install.sh              ← ワンコマンドインストーラー
vp-history
vp-view
README.md
LICENSE (MIT)
.gitignore (.env, バイナリ)
```

---

## 重要な設計判断と注意事項

### 1. アクセシビリティ権限問題 (最重要)
- **バイナリを再コンパイルするとmacOSがアクセシビリティ権限をリセットする**
- 毎回「システム設定 → プライバシーとセキュリティ → アクセシビリティ → VoiceToPrompt ON」が必要
- **対策**: バイナリは極力変更しない。設定変更は `system_prompt.txt` 等の外部ファイルで行う
- バイナリ変更が必要な場合: `tccutil reset Accessibility com.voicetoprompt.launcher` → 起動 → 設定画面で許可 → アプリ再起動

### 2. ホットキー方式
- **Carbon API `RegisterEventHotKey`** を使用 (NSEventのグローバルモニターはアクセシビリティ依存)
- コールバックはC関数 `hotkeyCallback` (グローバルスコープ) → `gApp?.toggle()`
- 現在のキー: **Shift+Space** (keycode=49, modifier=shiftKey)
- アクセシビリティが許可されていないとホットキーが届かない

### 3. Gemini API レート制限
- 無料枠: **20リクエスト/分**, 1500リクエスト/日
- **1回の音声入力 = 1 APIリクエスト** (以前は3並列で消費が激しかった)
- 429エラー時: 5秒待って次のモデルへフォールバック (`gemini-2.5-flash-lite` → `gemini-2.0-flash-lite` → `gemini-2.0-flash`)
- 全モデル失敗時: 元の音声テキストをそのままクリップボードにコピー

### 4. 音声認識の60秒制限
- macOS Speech Frameworkは約60秒で認識タスクが自動終了
- **セグメント方式**で対策: エラー発生 → 現在のテキストを `segments` に確定 → 新しいタスクを再起動
- オーディオタップ (`installTap`) は維持、認識タスクだけ再起動

### 5. 音声認識の誤変換修正
- Gemini APIで修正 (system_prompt.txtに定義)
- 例: パイソン→Python, 切ってハブ→GitHub, XOR→X, 完走→感想
- **意図の汲み取り**: 曖昧な表現をAIが文脈から補完 (ただし捏造はNG)

### 6. マイク問題
- `engine.stop(); engine.reset()` を録音開始時に毎回実行
- `AVAudioEngineConfigurationChange` を監視してデバイス変更に対応
- イヤホン抜き差し時に自動リセット

---

## 過去に発生したエラーと解決策

| エラー | 原因 | 解決策 |
|--------|------|--------|
| 「サーバーに接続できません」 | HTMLをfile://で開いた | サーバー経由 (http://localhost:8765) で開く |
| 429 RESOURCE_EXHAUSTED | APIレート制限 | 3並列→1順次に変更、5秒待ちフォールバック |
| XOR→X問題 | AIが勝手に解釈 | system_prompt.txtで「意味を変えない」を強調 |
| 長文が途切れる | maxOutputTokens=300 | 2000に固定 |
| ホットキーが効かない | アクセシビリティ未許可 | tccutilリセット→許可→アプリ再起動 |
| イヤホンでしかマイク使えない | デフォルト入力デバイス問題 | engine.reset() + デバイス変更監視 |
| バイナリ変更で権限リセット | macOSの仕様 | バイナリ変更を最小化 |

---

## ビルド手順

```bash
cd ~/Desktop/voice-input

# メインアプリ
swiftc -O -framework Cocoa -framework Carbon -framework Speech -framework AVFoundation \
  HotkeyLauncher.swift -o HotkeyLauncher

# インストール
APP=~/Applications/VoiceToPrompt.app
cp HotkeyLauncher "$APP/Contents/MacOS/VoiceToPrompt"
xattr -cr "$APP" && codesign -s - -f "$APP"

# アクセシビリティリセット (バイナリ変更後のみ)
tccutil reset Accessibility com.voicetoprompt.launcher
open "$APP"
# → システム設定でVoiceToPromptをON
# → pkill VoiceToPrompt && open "$APP"

# CLI (変更時のみ)
swiftc -O -framework Speech -framework AVFoundation \
  voice-input-cli.swift -o voice-input-cli
```

---

## API テスト

```bash
API_KEY=$(grep GEMINI_API_KEY ~/Desktop/voice-input/.env | sed 's/GEMINI_API_KEY=//')

# 簡易テスト
curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"Say OK"}]}]}' | python3 -c "import sys,json;d=json.loads(sys.stdin.read());print(d.get('candidates',[{}])[0].get('content',{}).get('parts',[{}])[0].get('text','ERROR'))"

# プロンプト変換テスト
SYSTEM=$(cat ~/Desktop/voice-input/system_prompt.txt)
# python3でJSON生成 → curl → 結果確認
```

---

## 今後の改善候補

- [ ] GitHub公開 (`gh repo create voice-to-prompt --public --push`)
- [ ] Whisper APIでの高精度音声認識オプション
- [ ] 多言語対応 (英語、中国語)
- [ ] プロンプトテンプレート機能
- [ ] 履歴の自動バックアップ (iCloud)

---

## セッション再開時のクイックスタート

```bash
# 状態確認
pgrep -f VoiceToPrompt && echo "App running" || echo "App not running"
cat ~/Desktop/voice-input/.env | head -1
shasum ~/Applications/VoiceToPrompt.app/Contents/MacOS/VoiceToPrompt

# アプリ起動
open ~/Applications/VoiceToPrompt.app

# テスト (osascriptでShift+Space送信)
osascript -e 'tell application "System Events" to key code 49 using {shift down}'
sleep 5
osascript -e 'tell application "System Events" to key code 49 using {shift down}'
sleep 8
osascript -e 'the clipboard'
```

---

*最終更新: 2026-04-02*
*バイナリハッシュ: 0cf325ceb7ebb634189b2c1ea8c87b7a646d357e*
