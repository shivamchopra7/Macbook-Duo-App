import AppKit
import Carbon

extension AppModel {
    func registerHotKey() {
        // App-targeted events (including keyboard accessibility tools) can bypass Carbon's
        // global hot-key dispatcher. Handle the same shortcuts in our local event queue.
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
            guard let self else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let escape = event.keyCode == UInt16(kVK_Escape) && (self.overlayVisible || self.demoRunning)
            let chord = event.keyCode == UInt16(kVK_ANSI_F) && mods == [.control,.option,.command]
            if escape || chord {
                self.pause(L10n.text("Stopped with the keyboard shortcut. Your desktop is clear."))
                return nil
            }
            return event
        }
        var eventType = EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _,_,context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async {
                let model = Unmanaged<AppModel>.fromOpaque(context).takeUnretainedValue()
                model.pause(L10n.text("Stopped with the keyboard shortcut. Your desktop is clear."))
            }
            return noErr
        },1,&eventType,context,&hotKeyHandler)
        let id = EventHotKeyID(signature:0x4C464C57,id:1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_F),UInt32(controlKey|optionKey|cmdKey),id,GetApplicationEventTarget(),0,&hotKey)
        if result != noErr { status = L10n.text("Global pause shortcut unavailable. Esc will remain available during the effect.") }
    }

    func registerEscape() -> Bool {
        if escapeKey != nil { return true }
        let id = EventHotKeyID(signature:0x4C464C57,id:2)
        return RegisterEventHotKey(UInt32(kVK_Escape),0,id,GetApplicationEventTarget(),0,&escapeKey) == noErr
    }
}
