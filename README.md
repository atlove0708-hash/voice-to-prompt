# Voice to Prompt

**話すだけでAIに渡す最適なプロンプトを自動生成する macOS アプリ (無料)**

言語化が苦手でも大丈夫。話すだけで、AIが意図を汲み取って最適な指示文に変換します。

## デモ

```
Shift+Space → 「えっとなんかPythonでウェブサイトのデータ取ってくるやつ作りたいんだけど」 → Shift+Space
```
↓ クリップボードに自動コピー:
> Pythonを使用してWebスクレイピングを行うスクリプトを作成してください。

## 特徴

- **Shift+Space** を押すだけで起動。もう一度押すと変換開始
- **オフライン音声認識** (macOS標準) + **AI変換** (Gemini API 無料)
- **忠実度チェック**: 言ってない内容を勝手に追加しない安全設計
- **メニューバー常駐**: Mac起動時に自動起動、邪魔にならない
- **履歴機能**: 過去のプロンプトを検索・再利用
- **ターミナル版** (`vp` コマンド) も付属

## インストール (3分)

```bash
git clone https://github.com/atlove0708-hash/voice-to-prompt.git
cd voice-to-prompt
bash install.sh
```

これだけ。インストーラーが全部やります:
1. 環境チェック (macOS, Swift)
2. コンパイル
3. アプリ作成 & メニューバーに常駐
4. APIキー設定 (無料、ブラウザが開きます)
5. アクセシビリティ許可の案内

### 必要なもの

- **macOS 13 (Ventura)** 以降
- **Xcode Command Line Tools** (なければインストーラーが案内します)
- **Googleアカウント** (無料APIキー取得用)

## 使い方

### ショートカットキー (おすすめ)

1. **Shift+Space** → 録音開始
2. 話す
3. **Shift+Space** → AI変換 → クリップボードにコピー
4. **Cmd+V** で貼り付け

### ターミナルから

```bash
vp
# 録音中... → 話す → Enter → 変換 → コピー
```

## アーキテクチャ

```
Shift+Space → macOS Speech Framework (オフライン音声認識)
                  ↓
            テキスト (日本語)
                  ↓
            Gemini API (無料)
            ・音声認識の誤変換修正
            ・意図を汲み取って補完 (控えめに)
            ・忠実度チェック → NGなら保守的に再生成
            ・プロンプトとして整形
                  ↓
            クリップボードにコピー
```

## プロジェクト構成

```
Sources/VoiceToPrompt/
  App/       main.swift, AppDelegate.swift     # エントリポイント
  Audio/     AudioEngine.swift                 # マイク管理
             SpeechRecognizer.swift            # 音声認識 (60秒制限対策付き)
  AI/        GeminiAPI.swift                   # API通信 (フォールバック付き)
             PromptProcessor.swift             # 忠実度チェック付き変換
             DefaultPrompts.swift              # プロンプト定義
  Hotkey/    HotkeyManager.swift               # Shift+Space
  UI/        Overlay.swift, MenuBarManager.swift, Notifier.swift
  History/   HistoryManager.swift              # 履歴 (JSON Lines)
  Config/    Config.swift, Logger.swift        # 設定・ログ
  Updater/   UpdateChecker.swift               # 自動更新確認
```

## カスタマイズ

### プロンプトの調整

`~/.local/share/voice-to-prompt/system_prompt.txt` を編集するだけ。再ビルド不要。

### APIキーの変更

```bash
echo "GEMINI_API_KEY=your-new-key" > ~/.local/share/voice-to-prompt/.env
```

## トラブルシューティング

| 症状 | 解決方法 |
|------|----------|
| Shift+Spaceが効かない | システム設定 → アクセシビリティ → VoiceToPrompt ON |
| マイクが見つかりません | システム設定 → マイク → VoiceToPrompt ON |
| API変換が失敗する | `vp` コマンドでAPIキーを再設定 |
| アプリが起動しない | `open ~/Applications/VoiceToPrompt.app` |

## ライセンス

MIT License
