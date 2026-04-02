import Cocoa

// ============================================================
//  フローティングオーバーレイ (ステータス表示)
// ============================================================

class Overlay {
    private var window: NSWindow?
    private var label: NSTextField?

    func show(_ text: String, color: NSColor = .white) {
        DispatchQueue.main.async {
            if self.window == nil {
                let w = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 480, height: 54),
                    styleMask: [.borderless], backing: .buffered, defer: false
                )
                w.level = .floating
                w.isOpaque = false
                w.hasShadow = true
                w.backgroundColor = NSColor.black.withAlphaComponent(0.88)
                w.contentView?.wantsLayer = true
                w.contentView?.layer?.cornerRadius = 14

                let l = NSTextField(labelWithString: "")
                l.frame = NSRect(x: 16, y: 12, width: 448, height: 30)
                l.font = NSFont.systemFont(ofSize: 14, weight: .medium)
                l.textColor = .white
                l.alignment = .center
                l.lineBreakMode = .byTruncatingTail
                w.contentView?.addSubview(l)
                self.label = l

                if let s = NSScreen.main {
                    w.setFrameOrigin(NSPoint(x: s.frame.midX - 240, y: s.frame.maxY - 110))
                }
                self.window = w
            }
            self.label?.stringValue = text
            self.label?.textColor = color
            self.window?.orderFront(nil)
        }
    }

    func hide() {
        DispatchQueue.main.async { self.window?.orderOut(nil) }
    }
}
