# Voice to Prompt 🎤✨

**話すだけでAIが最適なプロンプトを生成する macOS ツール（無料）**

言いたいことをうまく言語化できなくても大丈夫。  
あなたが話した言葉をAIが理解し、最適な指示文（プロンプト）に変換します。

```
Shift+Space → 話す → Shift+Space → Cmd+V
```

https://github.com/user-attachments/assets/demo.gif

---

## 特徴

- **ショートカット一発**: `Shift+Space` でどこからでも起動
- **ターミナル不要**: バックグラウンドで完結
- **意図を汲み取る**: 曖昧な表現をAIが補完
- **音声誤変換を自動修正**: 同音異義語・専門用語を文脈で修正
- **完全無料**: Google Gemini API の無料枠を使用
- **macOSネイティブ**: Swift製、追加パッケージ不要

## インストール（3分）

```bash
git clone https://github.com/takuro-kobayashi/voice-to-prompt.git
cd voice-to-prompt
bash install.sh
```

これだけ。あとは画面の指示に従うだけです。

### 必要なもの

- macOS 13 (Ventura) 以降
- Xcode Command Line Tools（なければインストーラーが案内します）
- Google アカウント（APIキー取得用、無料）

## 使い方

### 方法1: ショートカットキー（おすすめ）

| 操作 | 説明 |
|---|---|
| `Shift+Space` | 録音開始（画面上部にバーが出る） |
| 話す | リアルタイムで認識表示 |
| `Shift+Space` | 停止 → AI変換 → クリップボードにコピー |
| `Cmd+V` | 好きな場所に貼り付け |

### 方法2: ターミナルから

```bash
vp
```

→ 話す → Enter → Cmd+V

### 方法3: ダブルクリック

デスクトップの **「Voice to Prompt」** をダブルクリック

## 例

| あなたの音声 | 生成されるプロンプト |
|---|---|
| 「えっとなんかウェブサイト作りたいんだけどいい感じに」 | 洗練されたモダンなデザインのウェブサイトをHTML/CSS/JavaScriptで作成してください。 |
| 「パイソンでスクレーピングのやつ作って」 | Pythonでスクレイピングツールを作成してください。 |
| 「切ってハブにプッシュして完走もらいたい」 | GitHubにプッシュして感想をもらいたいです。 |
| 「Xをリサーチした上でこれが最適解か教えて」 | Xをリサーチした上で、これが最適解かどうか教えてください。 |

## 仕組み

```
🎤 音声入力
  ↓ macOS Speech Framework（オフライン）
📝 テキスト
  ↓ Gemini API（無料）
  ↓ 1. 音声認識の誤変換を修正
  ↓ 2. 意図を汲み取って補完
  ↓ 3. プロンプトとして整形
✨ 最適化プロンプト
  ↓
📋 クリップボードにコピー
```

## カスタマイズ

`~/.local/share/voice-to-prompt/system_prompt.txt` を編集するだけで  
AIの振る舞いを変更できます（再ビルド不要）。

## FAQ

**Q: 無料？**  
A: はい。Google Gemini API の無料枠（1日1500リクエスト）を使用します。

**Q: インターネット必要？**  
A: 音声認識はオフラインで動きます。プロンプト変換にインターネットが必要です。

**Q: Shift+Space が効かない**  
A: システム設定 → プライバシーとセキュリティ → アクセシビリティ で VoiceToPrompt を ON にしてください。

**Q: イヤホンでしかマイクが使えない**  
A: システム設定 → サウンド → 入力 で内蔵マイクを選択してください。アプリは録音開始時にデフォルトデバイスを自動検出します。

## アンインストール

```bash
rm -rf ~/Applications/VoiceToPrompt.app
rm -rf ~/.local/share/voice-to-prompt
rm -f ~/.local/bin/vp
rm -f ~/Desktop/"Voice to Prompt.command"
```

## ライセンス

MIT
