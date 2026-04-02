import Foundation

// ============================================================
//  macOS通知
// ============================================================

enum Notifier {
    static func send(_ title: String, _ message: String) {
        let t = title.replacingOccurrences(of: "\"", with: "'")
        let m = message
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\n", with: " ")
        let script = "display notification \"\(String(m.prefix(200)))\" with title \"\(t)\" sound name \"Glass\""
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        try? p.run()
    }
}
