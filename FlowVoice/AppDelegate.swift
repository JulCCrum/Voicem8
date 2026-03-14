import Cocoa
import AVFoundation
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyManager = HotkeyManager()
    private let audioRecorder = AudioRecorder()
    private var overlay: NSPanel?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var tickCount = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.debugLog("=== FlowVoice launched ===")
        Self.debugLog("API key set: \(!AppState.shared.apiKey.isEmpty)")
        requestAccessibilityIfNeeded()
        requestMicrophoneAccess()
        setupHotkey()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCancelRecording),
            name: .cancelRecording,
            object: nil
        )
    }

    // MARK: - Permissions

    private func requestAccessibilityIfNeeded() {
        let trusted = AXIsProcessTrusted()
        Self.debugLog("Accessibility trusted: \(trusted)")
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            Self.debugLog("Prompted user for accessibility access")
        }
    }

    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Microphone Access Required"
                    alert.informativeText = "FlowVoice needs microphone access to transcribe your voice."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyManager.onKeyDown = { [weak self] in
            self?.startRecording()
        }
        hotkeyManager.onKeyUp = { [weak self] in
            self?.stopRecordingAndTranscribe()
        }
        hotkeyManager.start()
    }

    // MARK: - Recording

    private func startRecording() {
        Self.debugLog("startRecording called")
        guard !AppState.shared.isRecording else { return }

        guard !AppState.shared.apiKey.isEmpty else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "API Key Required"
                alert.informativeText = "Click the mic icon in the menu bar and set your Groq API key."
                alert.alertStyle = .warning
                alert.runModal()
            }
            return
        }

        do {
            try audioRecorder.start()
            DispatchQueue.main.async {
                AppState.shared.isRecording = true
                AppState.shared.recordingDuration = 0
                self.showOverlay()
                self.startTimer()
            }
        } catch {
            print("Recording failed: \(error)")
        }
    }

    private func stopRecordingAndTranscribe() {
        Self.debugLog("stopRecordingAndTranscribe called, isRecording=\(AppState.shared.isRecording)")
        guard AppState.shared.isRecording else {
            Self.debugLog("Not recording, skipping")
            return
        }

        guard let audioURL = audioRecorder.stop() else {
            Self.debugLog("No audio URL after stop")
            return
        }

        Self.debugLog("Stopped recording: \(audioURL.lastPathComponent)")

        DispatchQueue.main.async {
            AppState.shared.isRecording = false
            AppState.shared.isTranscribing = true
            self.stopTimer()
            self.hideOverlay()
        }

        let apiKey = AppState.shared.apiKey

        Task {
            defer {
                try? FileManager.default.removeItem(at: audioURL)
            }

            do {
                Self.debugLog("Sending to Groq...")
                let text = try await GroqService.transcribe(fileURL: audioURL, apiKey: apiKey)
                Self.debugLog("Transcription result: \(text)")
                await MainActor.run {
                    AppState.shared.isTranscribing = false
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        Self.debugLog("Pasting text: \(trimmed)")
                        TextInjector.paste(trimmed)
                    } else {
                        Self.debugLog("Empty transcription, nothing to paste")
                    }
                }
            } catch {
                await MainActor.run {
                    AppState.shared.isTranscribing = false
                }
                Self.debugLog("Transcription FAILED: \(error)")
            }
        }
    }

    @objc private func handleCancelRecording() {
        audioRecorder.cancel()
        DispatchQueue.main.async {
            AppState.shared.isRecording = false
            self.stopTimer()
            self.hideOverlay()
        }
    }

    // MARK: - Overlay

    private func showOverlay() {
        if overlay == nil {
            overlay = OverlayPanel.create()
        }
        overlay?.orderFront(nil)
    }

    private func hideOverlay() {
        overlay?.orderOut(nil)
    }

    // MARK: - Timer

    private func startTimer() {
        tickCount = 0
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let level = self.audioRecorder.currentLevel()
            var levels = AppState.shared.audioLevels
            levels.removeFirst()
            levels.append(level)
            AppState.shared.audioLevels = levels

            self.tickCount += 1
            if self.tickCount % 20 == 0 {
                AppState.shared.recordingDuration += 1
            }
        }
    }

    private static func debugLog(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
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

    private func stopTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        AppState.shared.audioLevels = Array(repeating: 0, count: 5)
    }
}
