import Cocoa

// ============================================================
//  メニューバー管理
// ============================================================

class MenuBarManager {
    var statusItem: NSStatusItem!
    var onToggle: (() -> Void)?
    var onOpenHistory: (() -> Void)?
    var onCheckUpdate: (() -> Void)?
    var onQuit: (() -> Void)?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🎤"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Voice to Prompt v\(Config.version)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Shift+Space で音声入力", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "🎤 音声入力 開始/停止", action: #selector(toggleAction), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let historyItem = NSMenuItem(title: "📋 履歴を開く", action: #selector(openHistoryAction), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        let updateItem = NSMenuItem(title: "🔄 アップデート確認", action: #selector(checkUpdateAction), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "終了", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func setIcon(_ icon: String) {
        DispatchQueue.main.async { self.statusItem.button?.title = icon }
    }

    @objc private func toggleAction() { onToggle?() }
    @objc private func openHistoryAction() { onOpenHistory?() }
    @objc private func checkUpdateAction() { onCheckUpdate?() }
    @objc private func quitAction() { onQuit?() }
}
