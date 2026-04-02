import Cocoa

// ============================================================
//  Voice to Prompt v5.0
//  エントリポイント
// ============================================================

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.activate(ignoringOtherApps: false)
app.run()
