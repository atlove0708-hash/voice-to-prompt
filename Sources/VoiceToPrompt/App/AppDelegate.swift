import Cocoa
import Speech

// ============================================================
//  メインアプリケーション
//  各モジュールを組み合わせて動作を制御
// ============================================================

class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBar = MenuBarManager()
    let overlay = Overlay()
    let hotkey = HotkeyManager()
    let audioManager = AudioEngineManager()
    let speechManager = SpeechRecognizerManager()

    var apiKey = ""
    var isRecording = false
    var isProcessing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("VoiceToPrompt v\(Config.version) starting")
        apiKey = Config.loadApiKey()

        // メニューバー
        menuBar.setup()
        menuBar.onToggle = { [weak self] in self?.toggle() }
        menuBar.onOpenHistory = { HistoryManager.openViewer() }
        menuBar.onCheckUpdate = { [weak self] in self?.checkForUpdate() }
        menuBar.onQuit = { NSApp.terminate(nil) }

        // ホットキー
        hotkey.onHotkey = { [weak self] in self?.toggle() }
        hotkey.register()

        // オーディオデバイス変更
        audioManager.onDeviceChanged = { [weak self] in
            guard let self = self else { return }
            self.audioManager.handleDeviceChange(isRecording: self.isRecording)
        }

        // 音声認識テキスト更新
        speechManager.onTranscriptUpdate = { [weak self] text in
            let display = text.count > 40 ? "…" + String(text.suffix(40)) : text
            self?.overlay.show("🎤 \(display)", color: .systemGreen)
        }

        // 権限リクエスト
        SpeechRecognizerManager.requestAuthorization { granted in
            if !granted { Log.speech.warning("Speech recognition not authorized") }
        }

        // 起動時にアップデート確認（バックグラウンド）
        checkForUpdate(silent: true)

        if apiKey.isEmpty {
            Notifier.send("Voice to Prompt", "APIキーが未設定です。ターミナルで vp を実行してください。")
        }

        Log.app.info("Ready")
    }

    // --- トグル ---
    func toggle() {
        if isProcessing { return }
        isRecording ? stopRecording() : startRecording()
    }

    // --- 録音開始 ---
    func startRecording() {
        guard !isRecording else { return }
        apiKey = Config.loadApiKey()
        if apiKey.isEmpty {
            overlay.show("❌ APIキー未設定 (ターミナルで vp)", color: .systemRed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.overlay.hide() }
            return
        }

        isRecording = true
        menuBar.setIcon("⏺")
        overlay.show("🎤 話してください… (Shift+Space で終了)", color: .systemRed)

        speechManager.start()

        do {
            try audioManager.startCapture { [weak self] buffer in
                self?.speechManager.appendBuffer(buffer)
            }
        } catch {
            Log.audio.error("Failed to start: \(error.localizedDescription)")
            overlay.show("❌ \(error.localizedDescription)", color: .systemRed)
            isRecording = false
            menuBar.setIcon("🎤")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.overlay.hide() }
        }
    }

    // --- 録音停止 ---
    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        isProcessing = true

        audioManager.stopCapture()
        let text = speechManager.stop()

        menuBar.setIcon("⏳")

        if text.isEmpty {
            overlay.show("音声が検出されませんでした", color: .systemYellow)
            isProcessing = false
            menuBar.setIcon("🎤")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.overlay.hide() }
            return
        }

        // プロンプト変換（忠実度チェック付き）
        PromptProcessor.process(rawText: text, apiKey: apiKey, overlay: overlay) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isProcessing = false
                self.menuBar.setIcon("🎤")

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result.prompt, forType: .string)

                HistoryManager.save(
                    raw: result.original,
                    prompt: result.prompt,
                    success: result.success,
                    wasConservative: result.wasConservative
                )

                if result.success {
                    let suffix = result.wasConservative ? " (控えめ変換)" : ""
                    self.overlay.show("✅ Cmd+V で貼り付け\(suffix)", color: .systemGreen)
                    Notifier.send("プロンプト生成完了", String(result.prompt.prefix(100)))
                } else {
                    self.overlay.show("⚠️ 元テキストをコピーしました", color: .systemYellow)
                    Notifier.send("Voice to Prompt", "元テキストをコピーしました")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self.overlay.hide() }
            }
        }
    }

    // --- アップデート確認 ---
    func checkForUpdate(silent: Bool = false) {
        UpdateChecker.check { release in
            DispatchQueue.main.async {
                if let release = release {
                    Notifier.send(
                        "アップデートあり: v\(release.version)",
                        "最新版をダウンロードしてください"
                    )
                } else if !silent {
                    Notifier.send("Voice to Prompt", "最新バージョンです (v\(Config.version))")
                }
            }
        }
    }
}
