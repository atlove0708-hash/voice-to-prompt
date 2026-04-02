import Foundation

// ============================================================
//  設定管理 - 環境変数、ファイルパス、定数
// ============================================================

enum Config {
    static let bundleID = "com.voicetoprompt.launcher"
    static let appName = "VoiceToPrompt"
    static let version = "5.0.0"
    static let hotkeyCode: UInt32 = 49  // Space
    static let hotkeyModifier: UInt32 = 0x0200  // shiftKey

    // --- パス ---
    static let baseDir = NSHomeDirectory() + "/Desktop/voice-input"
    static let historyDir = baseDir + "/history"
    static let historyFile = historyDir + "/voice_history.jsonl"
    static let envFile = baseDir + "/.env"

    // 検索するディレクトリ一覧
    static let searchDirs = [
        baseDir + "/",
        NSHomeDirectory() + "/.local/share/voice-to-prompt/",
    ]

    // --- API ---
    static let geminiModels = [
        "gemini-2.5-flash-lite",
        "gemini-2.0-flash-lite",
        "gemini-2.0-flash",
    ]
    static let apiTimeout: TimeInterval = 12
    static let rateLimitRetryDelay: TimeInterval = 5
    static let maxOutputTokens = 2000
    static let temperature = 0.2

    // --- 忠実度チェック ---
    static let maxLengthRatio: Double = 2.5  // 出力/入力の長さ比率上限
    static let conservativeTemperature = 0.1

    // --- ファイル読み込み ---
    static func loadFile(_ name: String) -> String? {
        for dir in searchDirs {
            if let c = try? String(contentsOfFile: dir + name, encoding: .utf8), !c.isEmpty {
                return c.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    static func loadApiKey() -> String {
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

    static func loadSystemPrompt() -> String {
        return loadFile("system_prompt.txt") ?? DefaultPrompts.system
    }
}
