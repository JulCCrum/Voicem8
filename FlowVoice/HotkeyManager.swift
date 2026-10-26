import Cocoa
import Carbon.HIToolbox
import ApplicationServices

final class HotkeyManager {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isFnPressed = false
    private var activeFnKeyCode: CGKeyCode?

    func start() {
        stop()

        let mask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << 14) // NX_SYSDEFINED — fn/Globe key on many keyboards arrives here

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }

                let manager = Unmanaged<HotkeyManager>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()
                manager.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            log("Failed to create CGEvent tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        log("Started CGEvent tap")
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        isFnPressed = false
        activeFnKeyCode = nil
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                log("Re-enabled CGEvent tap after \(type)")
            }
            return
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        log("event type=\(type.rawValue) keyCode=\(keyCode) flags=\(flags.rawValue)")

        // Trigger on Option key flagsChanged. Left Option = 58, Right Option = 61.
        guard type == .flagsChanged && (keyCode == 58 || keyCode == 61) else { return }

        let optDown = flags.contains(.maskAlternate)
        if optDown && !isFnPressed {
            isFnPressed = true
            activeFnKeyCode = keyCode
            onKeyDown?()
        } else if !optDown && isFnPressed {
            isFnPressed = false
            activeFnKeyCode = nil
            onKeyUp?()
        }
    }

    private func log(_ msg: String) {
        let line = "[\(Date())] HotkeyManager: \(msg)\n"
        let logPath = URL(fileURLWithPath: "/tmp/flowvoice_debug.log")
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? data.write(to: logPath)
            }
        }
    }
}
