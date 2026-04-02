import AVFoundation
import Foundation

// ============================================================
//  オーディオエンジン管理
//  エンジンのライフサイクルとデバイス変更を一元管理
// ============================================================

class AudioEngineManager {
    private(set) var engine = AVAudioEngine()
    private var deviceObserver: NSObjectProtocol?

    var onDeviceChanged: (() -> Void)?

    init() {
        observeDeviceChanges()
        prewarm()
    }

    /// エンジンを事前準備（Shift+Space時の起動を高速化）
    func prewarm() {
        engine = AVAudioEngine()
        reobserve()
        let _ = engine.inputNode  // ハードウェア初期化
        engine.prepare()
        Log.audio.info("Engine prewarmed")
    }

    /// 現在のフォーマットを取得（無効なら再作成して再試行）
    func getValidFormat() -> AVAudioFormat? {
        var fmt = engine.inputNode.outputFormat(forBus: 0)
        if fmt.sampleRate == 0 || fmt.channelCount == 0 {
            Log.audio.warning("Invalid format, recreating engine")
            prewarm()
            fmt = engine.inputNode.outputFormat(forBus: 0)
        }
        guard fmt.sampleRate > 0, fmt.channelCount > 0 else {
            Log.audio.error("No valid audio input found")
            return nil
        }
        return fmt
    }

    /// タップを追加してエンジンを開始
    func startCapture(handler: @escaping (AVAudioPCMBuffer) -> Void) throws {
        guard let fmt = getValidFormat() else {
            throw AudioError.noMicrophone
        }
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buf, _ in
            handler(buf)
        }
        try engine.start()
        Log.audio.info("Capture started (rate: \(fmt.sampleRate), ch: \(fmt.channelCount))")
    }

    /// 停止してタップを除去、次回に備えてプリウォーム
    func stopCapture() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        engine.reset()
        prewarm()
        Log.audio.info("Capture stopped, engine prewarmed for next use")
    }

    /// 録音中のデバイス変更対応
    func handleDeviceChange(isRecording: Bool) {
        if isRecording {
            engine.stop()
            engine.reset()
            engine.prepare()
            try? engine.start()
            Log.audio.info("Reconnected after device change (recording)")
        } else {
            prewarm()
            Log.audio.info("Reprewarm after device change (idle)")
        }
    }

    // --- private ---

    private func observeDeviceChanges() {
        reobserve()
    }

    private func reobserve() {
        if let old = deviceObserver {
            NotificationCenter.default.removeObserver(old)
        }
        deviceObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.onDeviceChanged?()
        }
    }

    deinit {
        if let obs = deviceObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}

enum AudioError: LocalizedError {
    case noMicrophone

    var errorDescription: String? {
        switch self {
        case .noMicrophone: return "マイクが見つかりません"
        }
    }
}
