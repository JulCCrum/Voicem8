import Cocoa
import Carbon.HIToolbox
import ApplicationServices

enum TextInjector {
    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        debugLog("Clipboard set, scheduling paste...")

        // Delay to let Fn key modifier state settle before simulating Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let trusted = AXIsProcessTrusted()
            debugLog("Accessibility trusted: \(trusted)")

            if trusted {
                debugLog("Using CGEvent paste")
                simulateCommandV()
            } else {
                debugLog("No accessibility — using AppleScript paste")
                appleScriptPaste()
            }

            // Restore previous clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                if let previous = previous {
                    pasteboard.setString(previous, forType: .string)
                }
            }
        }
    }

    private static func simulateCommandV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
        debugLog("CGEvent Cmd+V posted")
    }

    private static func appleScriptPaste() {
        let script = NSAppleScript(source: """
            tell application "System Events"
                keystroke "v" using command down
            end tell
        """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        if let error = error {
            debugLog("AppleScript error: \(error)")
        }
    }

    private static func debugLog(_ msg: String) {
        let line = "[FlowVoice TextInjector] \(msg)\n"
        let logPath = URL(fileURLWithPath: "/tmp/flowvoice_debug.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath.path) {
                if let handle = try? FileHandle(forWritingTo: logPath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logPath)
            }
        }
    }
}
