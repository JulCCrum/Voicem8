import SwiftUI

@main
struct FlowVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            if state.isRecording {
                Label("Recording...", systemImage: "waveform")
                    .foregroundStyle(.red)
            } else if state.isTranscribing {
                Label("Transcribing...", systemImage: "ellipsis")
            } else {
                Label("Ready", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }

            Divider()

            Text("Hold Fn to dictate")
                .font(.caption)

            Divider()

            Button("Set API Key...") {
                promptForAPIKey()
            }

            Button("Quit FlowVoice") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: state.isRecording ? "waveform" : "mic.fill")
        }
    }

    private func promptForAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Groq API Key"
        alert.informativeText = "Enter your Groq API key.\nGet one free at console.groq.com"
        alert.alertStyle = .informational

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.stringValue = AppState.shared.apiKey
        input.placeholderString = "gsk_..."
        alert.accessoryView = input

        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            AppState.shared.apiKey = input.stringValue
        }
    }
}
