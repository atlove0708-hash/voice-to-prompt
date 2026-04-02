import Foundation
import os.log

// ============================================================
//  ログ管理 - os_log ベースの構造化ログ
//  30年後も動くようにApple標準のos.logを使用
// ============================================================

enum Log {
    private static let subsystem = Config.bundleID

    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let speech = Logger(subsystem: subsystem, category: "speech")
    static let api = Logger(subsystem: subsystem, category: "api")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let app = Logger(subsystem: subsystem, category: "app")
    static let update = Logger(subsystem: subsystem, category: "update")
}
