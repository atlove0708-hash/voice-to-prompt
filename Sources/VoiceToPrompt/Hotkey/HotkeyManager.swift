import Carbon
import Foundation

// ============================================================
//  ホットキー管理 (Carbon API)
//  将来的にCarbonが廃止されたらここだけ差し替え
// ============================================================

class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    var onHotkey: (() -> Void)?

    func register() {
        let id = EventHotKeyID(signature: OSType(0x56505450), id: 1)
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // グローバルコールバックからインスタンスメソッドを呼ぶためにstaticに保持
        HotkeyManager.shared = self

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyCallbackFunc,
            1, &spec, nil, nil
        )
        RegisterEventHotKey(
            Config.hotkeyCode,
            Config.hotkeyModifier,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        Log.hotkey.info("Hotkey registered: Shift+Space")
    }

    // --- static callback bridge ---
    static var shared: HotkeyManager?
}

// Carbon APIのコールバックはグローバルC関数である必要がある
private func hotkeyCallbackFunc(
    _: EventHandlerCallRef?, _: EventRef?, _: UnsafeMutableRawPointer?
) -> OSStatus {
    HotkeyManager.shared?.onHotkey?()
    return noErr
}
