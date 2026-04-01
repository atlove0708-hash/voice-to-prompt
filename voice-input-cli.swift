#!/usr/bin/env swift
//
// voice-input-cli: Enterで停止する音声入力CLIツール
// 使い方: voice-input-cli → 話す → Enter → stdout にテキスト出力
//

import Foundation
import Speech
import AVFoundation

let audioEngine = AVAudioEngine()
var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
var recognitionTask: SFSpeechRecognitionTask?
let locale = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ja-JP"
guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) else {
    FileHandle.standardError.write("  対応していない言語です: \(locale)\n".data(using: .utf8)!)
    exit(1)
}
var currentTranscript = ""

// 権限リクエスト
let sem = DispatchSemaphore(value: 0)
SFSpeechRecognizer.requestAuthorization { status in
    if status != .authorized {
        FileHandle.standardError.write("  音声認識の権限を許可してください。\n".data(using: .utf8)!)
        exit(1)
    }
    sem.signal()
}
sem.wait()

// 音声入力開始
let inputNode = audioEngine.inputNode
let fmt = inputNode.outputFormat(forBus: 0)

recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
recognitionRequest?.shouldReportPartialResults = true
if #available(macOS 13, *) {
    recognitionRequest?.addsPunctuation = true
}

recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { result, error in
    if let result = result {
        currentTranscript = result.bestTranscription.formattedString
        FileHandle.standardError.write("\r\u{1B}[K  🎤 \(currentTranscript)".data(using: .utf8)!)
    }
}

inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buffer, _ in
    recognitionRequest?.append(buffer)
}

audioEngine.prepare()
do { try audioEngine.start() }
catch {
    FileHandle.standardError.write("  マイク起動失敗\n".data(using: .utf8)!)
    exit(1)
}

FileHandle.standardError.write("  (Enter で終了)\n".data(using: .utf8)!)

// Enterキー待ち
DispatchQueue.global().async {
    let _ = readLine()
    DispatchQueue.main.async {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            FileHandle.standardError.write("\r\u{1B}[K".data(using: .utf8)!)
            if !currentTranscript.isEmpty { print(currentTranscript) }
            exit(0)
        }
    }
}

RunLoop.main.run()
