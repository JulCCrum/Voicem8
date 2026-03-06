import Cocoa
import AVFoundation
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyManager = HotkeyManager()
    private let audioRecorder = AudioRecorder()
    private var overlay: NSPanel?
    private var recordingTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
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
        guard AppState.shared.isRecording else { return }

        guard let audioURL = audioRecorder.stop() else { return }

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
                let text = try await GroqService.transcribe(fileURL: audioURL, apiKey: apiKey)
                await MainActor.run {
                    AppState.shared.isTranscribing = false
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        TextInjector.paste(trimmed)
                    }
                }
            } catch {
                await MainActor.run {
                    AppState.shared.isTranscribing = false
                }
                print("Transcription failed: \(error)")
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
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            AppState.shared.recordingDuration += 1
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}
