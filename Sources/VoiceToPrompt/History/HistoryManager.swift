import Foundation

// ============================================================
//  履歴管理 (JSON Lines形式)
// ============================================================

enum HistoryManager {

    static func save(raw: String, prompt: String, success: Bool, wasConservative: Bool = false) {
        ensureDir()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        let entry: [String: Any] = [
            "timestamp": df.string(from: Date()),
            "raw": raw,
            "prompt": prompt,
            "success": success,
            "conservative": wasConservative,
            "version": Config.version,
            "id": UUID().uuidString,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: entry),
              let line = String(data: data, encoding: .utf8)
        else { return }
        let lineData = (line + "\n").data(using: .utf8)!

        if FileManager.default.fileExists(atPath: Config.historyFile) {
            if let fh = FileHandle(forWritingAtPath: Config.historyFile) {
                fh.seekToEndOfFile()
                fh.write(lineData)
                fh.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: Config.historyFile, contents: lineData)
        }
        Log.app.info("History saved: \(raw.prefix(50))...")
    }

    static func openViewer() {
        ensureDir()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", "\(NSHomeDirectory())/.local/bin/vp-view"]
        try? p.run()
    }

    private static func ensureDir() {
        try? FileManager.default.createDirectory(
            atPath: Config.historyDir, withIntermediateDirectories: true
        )
    }
}
