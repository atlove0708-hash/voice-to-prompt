import Foundation
import Speech

// ============================================================
//  音声認識管理
//  60秒制限のセグメント分割、認識タスクのライフサイクル管理
// ============================================================

class SpeechRecognizerManager {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var segments: [String] = []
    private var currentSegment = ""
    private var isActive = false

    var onTranscriptUpdate: ((String) -> Void)?

    var transcript: String {
        (segments + [currentSegment]).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 認識開始
    func start() {
        isActive = true
        segments = []
        currentSegment = ""
        startTask()
    }

    /// バッファを認識リクエストに追加
    func appendBuffer(_ buffer: AVFoundation.AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    /// 認識停止して最終テキストを返す
    func stop() -> String {
        isActive = false
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil

        if !currentSegment.isEmpty {
            segments.append(currentSegment)
            currentSegment = ""
        }
        let result = segments.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        segments = []
        Log.speech.info("Final transcript: \(result.prefix(100))...")
        return result
    }

    /// 権限リクエスト
    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            completion(status == .authorized)
        }
    }

    // --- 認識タスク (60秒制限対策: エラー時に自動再起動) ---
    private func startTask() {
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        if #available(macOS 13, *) {
            request?.addsPunctuation = true
        }

        guard let request = request else { return }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self, self.isActive else { return }

            if let r = result {
                self.currentSegment = r.bestTranscription.formattedString
                self.onTranscriptUpdate?(self.transcript)
            }

            if error != nil, self.isActive {
                Log.speech.info("Recognition task ended, restarting segment")
                if !self.currentSegment.isEmpty {
                    self.segments.append(self.currentSegment)
                    self.currentSegment = ""
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if self.isActive { self.startTask() }
                }
            }
        }
    }
}
