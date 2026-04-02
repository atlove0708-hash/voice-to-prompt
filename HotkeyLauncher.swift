import Cocoa
import Carbon
import Speech
import AVFoundation

// ============================================================
//  Voice to Prompt v4.0
//  Shift+Space → 話す → Shift+Space → Cmd+V
//
//  v4.0: 長文対応、意図汲み取り精度向上、60秒制限完全対策
// ============================================================

// ============================================================
//  履歴保存 (JSON Lines形式、自動バックアップ)
// ============================================================
let HISTORY_DIR = NSHomeDirectory() + "/Desktop/voice-input/history"
let HISTORY_FILE = HISTORY_DIR + "/voice_history.jsonl"

func ensureHistoryDir() {
    try? FileManager.default.createDirectory(atPath: HISTORY_DIR, withIntermediateDirectories: true)
}

func saveHistory(raw: String, prompt: String, success: Bool) {
    ensureHistoryDir()
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    df.locale = Locale(identifier: "en_US_POSIX")
    let entry: [String: Any] = [
        "timestamp": df.string(from: Date()),
        "raw": raw,
        "prompt": prompt,
        "success": success,
        "id": UUID().uuidString
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: entry),
          let line = String(data: data, encoding: .utf8) else { return }
    let lineData = (line + "\n").data(using: .utf8)!

    if FileManager.default.fileExists(atPath: HISTORY_FILE) {
        if let fh = FileHandle(forWritingAtPath: HISTORY_FILE) {
            fh.seekToEndOfFile()
            fh.write(lineData)
            fh.closeFile()
        }
    } else {
        FileManager.default.createFile(atPath: HISTORY_FILE, contents: lineData)
    }
}

// --- ファイル読み込み ---
func loadFile(_ name: String) -> String? {
    for dir in [
        NSHomeDirectory() + "/Desktop/voice-input/",
        NSHomeDirectory() + "/.local/share/voice-to-prompt/",
    ] {
        if let c = try? String(contentsOfFile: dir + name, encoding: .utf8), !c.isEmpty {
            return c.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return nil
}

func loadApiKey() -> String {
    if let content = loadFile(".env") {
        for line in content.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("GEMINI_API_KEY=") {
                return String(t.dropFirst("GEMINI_API_KEY=".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            }
        }
    }
    return ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
}

// ============================================================
//  Gemini API (並列リクエスト、最速応答を採用)
// ============================================================
// Gemini API: 1モデルずつ順次試行 (レート制限対策: 1回の入力で1リクエストのみ)
// 429の場合だけ次のモデルへフォールバック
func geminiRace(system: String, user: String, apiKey: String, done: @escaping (String?) -> Void) {
    let models = ["gemini-2.5-flash-lite", "gemini-2.0-flash-lite", "gemini-2.0-flash"]

    func tryModel(_ i: Int) {
        guard i < models.count else { done(nil); return }
        let model = models[i]
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 12
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": system]]],
            "contents": [["parts": [["text": user]]]],
            "generationConfig": ["maxOutputTokens": 2000, "temperature": 0.2]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0

            if code == 429 {
                // レート制限: 5秒待って次のモデル
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) { tryModel(i + 1) }
                return
            }
            if code == 404 {
                tryModel(i + 1)
                return
            }

            guard code == 200, let data = data,
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let c = (j["candidates"] as? [[String: Any]])?.first,
                  let p = (c["content"] as? [String: Any])?["parts"] as? [[String: Any]],
                  let t = p.first?["text"] as? String, !t.isEmpty
            else { tryModel(i + 1); return }

            done(t)
        }.resume()
    }
    tryModel(0)
}

// ============================================================
//  音声 → プロンプト変換
// ============================================================
let DEFAULT_SYSTEM = """
あなたは「言いたいことを最高の指示文に変える」アシスタントです。
音声入力された日本語テキストを、AIに渡す指示文（プロンプト）として最適化してください。

多くの人は自分の考えを完璧に言語化できません。あなたの仕事は、ユーザーが「本当に伝えたいこと」を読み取り、AIが正確に理解できる指示文に変えることです。

## Step 1: 音声認識の誤変換を修正
- 同音異義語を文脈から修正（紀行→機構、完走→感想、異動→移動、回折→解決、換装→感想）
- IT用語の誤認識を修正（パイソン→Python、リアクト→React、切ってハブ→GitHub、エーピーアイ→API）
- 英字の誤認識を修正（XOR→X など文脈から判断）
- カタカナ語の修正（スクレーピング→スクレイピング）
- 文脈上ありえない単語を修正

## Step 2: 意図を汲み取って指示文を補完
ユーザーの発言から「本当にやりたいこと」を読み取り、AIが実行しやすい指示文に補完してください。
言語化が苦手な人でも、あなたが意図を正しく汲み取れば、最高のプロンプトになります。

### 補完してOK（積極的にやる）
- 技術的に明らかに必要な前提を追加（「ウェブサイト作って」→使用技術を明記）
- 漠然とした形容詞をより具体的な表現に（「いい感じ」→「洗練された読みやすい」）
- 出力形式の明確化（コードが必要そうなら「実装可能なコード例を含めて」）
- 文脈から明白な目的の明記
- 複数の要件が混ざっている場合の箇条書き化
- 暗黙の前提条件の明文化（「エラー出る」→「以下のエラーの原因と解決策を」）

### 補完NG（絶対やらない）
- ユーザーが全く触れていないトピックの追加
- 具体的な数値の捏造（予算、人数、期限、色コードなど）
- ターゲット層やペルソナの捏造
- ユーザーの意図と矛盾する内容
- 元の発言にない技術スタック（ユーザーがPythonと言ったのにGoで書くなど）

## Step 3: プロンプトとして整形
- 「えっと」「なんか」「みたいな」「的な」「っていうか」等の口語を除去
- 「〜してください」の丁寧な指示形にする
- 複数の要件がある場合は箇条書きで構造化
- 1文の入力には1-2文で返す。長い入力にはそれに応じた長さで

## 出力ルール
- 最適化後のプロンプトのみ出力
- 「以下が最適化結果です」等の前置きは一切不要
- 補足説明も不要
- 入力テキスト全体を漏れなく反映すること（長文でも省略しない）
"""

func processVoice(_ rawText: String, apiKey: String, overlay: Overlay, done: @escaping (String?) -> Void) {
    let system = loadFile("system_prompt.txt") ?? DEFAULT_SYSTEM
    let user = "以下の音声テキストを最適なプロンプトに変換してください:\n\n\(rawText)"
    overlay.show("✨ 変換中…", color: .systemCyan)
    geminiRace(system: system, user: user, apiKey: apiKey) { result in done(result) }
}

// ============================================================
//  通知
// ============================================================
func notify(_ title: String, _ msg: String) {
    let t = title.replacingOccurrences(of: "\"", with: "'")
    let m = msg.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: " ")
    let s = "display notification \"\(String(m.prefix(200)))\" with title \"\(t)\" sound name \"Glass\""
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); p.arguments = ["-e", s]
    try? p.run()
}

// ============================================================
//  フローティングオーバーレイ
// ============================================================
class Overlay {
    var win: NSWindow?
    var lbl: NSTextField?
    func show(_ text: String, color: NSColor = .white) {
        DispatchQueue.main.async {
            if self.win == nil {
                let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 54),
                    styleMask: [.borderless], backing: .buffered, defer: false)
                w.level = .floating; w.isOpaque = false; w.hasShadow = true
                w.backgroundColor = NSColor.black.withAlphaComponent(0.88)
                w.contentView?.wantsLayer = true; w.contentView?.layer?.cornerRadius = 14
                let l = NSTextField(labelWithString: "")
                l.frame = NSRect(x: 16, y: 12, width: 448, height: 30)
                l.font = NSFont.systemFont(ofSize: 14, weight: .medium)
                l.textColor = .white; l.alignment = .center; l.lineBreakMode = .byTruncatingTail
                w.contentView?.addSubview(l); self.lbl = l
                if let s = NSScreen.main {
                    w.setFrameOrigin(NSPoint(x: s.frame.midX - 240, y: s.frame.maxY - 110))
                }
                self.win = w
            }
            self.lbl?.stringValue = text; self.lbl?.textColor = color; self.win?.orderFront(nil)
        }
    }
    func hide() { DispatchQueue.main.async { self.win?.orderOut(nil) } }
}

// ============================================================
//  メインアプリ
// ============================================================
class App: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let overlay = Overlay()
    var isRecording = false
    var engine = AVAudioEngine()
    var recReq: SFSpeechAudioBufferRecognitionRequest?
    var recTask: SFSpeechRecognitionTask?
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    var segments: [String] = []       // 60秒ごとの確定テキスト
    var currentSegment = ""           // 現在のセグメントのテキスト
    var apiKey = ""
    var isProcessing = false

    var transcript: String {
        (segments + [currentSegment]).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        apiKey = loadApiKey()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🎤"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Shift+Space で音声入力", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "🎤 音声入力 開始/停止", action: #selector(toggle), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "📋 履歴を開く", action: #selector(openHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu

        // Shift+Space
        let id = EventHotKeyID(signature: OSType(0x56505450), id: 1)
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        gApp = self
        InstallEventHandler(GetApplicationEventTarget(), hotkeyCallback, 1, &spec, nil, nil)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(49, UInt32(shiftKey), id, GetApplicationEventTarget(), 0, &ref)

        SFSpeechRecognizer.requestAuthorization { _ in }

        NotificationCenter.default.addObserver(
            self, selector: #selector(audioDeviceChanged),
            name: .AVAudioEngineConfigurationChange, object: engine
        )

        if apiKey.isEmpty {
            notify("Voice to Prompt", "APIキーが未設定です。ターミナルで vp を実行してください。")
        }
    }

    @objc func audioDeviceChanged(_ n: Notification) {
        if isRecording {
            engine.stop(); engine.reset(); engine.prepare(); try? engine.start()
        }
    }

    @objc func toggle() {
        if isProcessing { return }
        isRecording ? stopRec() : startRec()
    }

    // ---- 録音開始 ----
    func startRec() {
        guard !isRecording else { return }
        apiKey = loadApiKey()
        if apiKey.isEmpty {
            overlay.show("❌ APIキー未設定 (ターミナルで vp)", color: .systemRed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.overlay.hide() }
            return
        }

        isRecording = true
        segments = []; currentSegment = ""
        DispatchQueue.main.async { self.statusItem.button?.title = "⏺" }
        overlay.show("🎤 話してください… (Shift+Space で終了)", color: .systemRed)

        engine.stop(); engine.reset()
        startRecognitionTask()

        let node = engine.inputNode
        node.installTap(onBus: 0, bufferSize: 1024, format: node.outputFormat(forBus: 0)) { [weak self] buf, _ in
            self?.recReq?.append(buf)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            overlay.show("❌ マイク起動失敗", color: .systemRed)
            isRecording = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.overlay.hide() }
        }
    }

    // ---- 認識タスク開始 (60秒制限対策: エラー時に自動再起動) ----
    func startRecognitionTask() {
        recReq = SFSpeechAudioBufferRecognitionRequest()
        recReq?.shouldReportPartialResults = true
        if #available(macOS 13, *) { recReq?.addsPunctuation = true }

        recTask = recognizer.recognitionTask(with: recReq!) { [weak self] result, error in
            guard let self = self, self.isRecording else { return }

            if let r = result {
                self.currentSegment = r.bestTranscription.formattedString
                let full = self.transcript
                let display = full.count > 40 ? "…" + String(full.suffix(40)) : full
                self.overlay.show("🎤 \(display)", color: .systemGreen)
            }

            if let error = error {
                // 60秒制限やネットワークエラー → セグメント確定 & 再起動
                let nsErr = error as NSError
                if self.isRecording {
                    // 現在のセグメントを確定
                    if !self.currentSegment.isEmpty {
                        self.segments.append(self.currentSegment)
                        self.currentSegment = ""
                    }
                    // 少し待って再起動 (タップは維持されているのでバッファは流れ続ける)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if self.isRecording { self.startRecognitionTask() }
                    }
                }
            }
        }
    }

    // ---- 録音停止 ----
    func stopRec() {
        guard isRecording else { return }
        isRecording = false; isProcessing = true

        engine.stop(); engine.inputNode.removeTap(onBus: 0)
        recReq?.endAudio(); recTask?.cancel()
        DispatchQueue.main.async { self.statusItem.button?.title = "⏳" }

        // 最後のセグメントを確定
        if !currentSegment.isEmpty { segments.append(currentSegment); currentSegment = "" }

        let text = segments.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            overlay.show("音声が検出されませんでした", color: .systemYellow)
            isProcessing = false
            DispatchQueue.main.async { self.statusItem.button?.title = "🎤" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.overlay.hide() }
            return
        }

        processVoice(text, apiKey: apiKey, overlay: overlay) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isProcessing = false
                self.statusItem.button?.title = "🎤"

                let ok = result != nil && !result!.isEmpty
                let output = ok ? result! : text
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(output, forType: .string)

                // 履歴保存 (元テキスト + 変換後プロンプト)
                saveHistory(raw: text, prompt: output, success: ok)

                if ok {
                    self.overlay.show("✅ Cmd+V で貼り付け", color: .systemGreen)
                    notify("プロンプト生成完了", String(output.prefix(100)))
                } else {
                    self.overlay.show("⚠️ 元テキストをコピーしました", color: .systemYellow)
                    notify("Voice to Prompt", "元テキストをコピーしました")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self.overlay.hide() }
            }
        }
    }

    @objc func openHistory() {
        ensureHistoryDir()
        // vp-view でHTMLビューアを開く
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", "\(NSHomeDirectory())/.local/bin/vp-view"]
        try? p.run()
    }

    @objc func quit() { NSApp.terminate(nil) }
}

// --- ホットキー ---
var gApp: App?
func hotkeyCallback(_: EventHandlerCallRef?, _: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    gApp?.toggle(); return noErr
}

// --- 起動 ---
let a = NSApplication.shared
a.setActivationPolicy(.accessory)
let d = App(); a.delegate = d
a.activate(ignoringOtherApps: false)
a.run()
