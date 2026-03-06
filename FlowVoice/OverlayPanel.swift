import SwiftUI

enum OverlayPanel {
    static func create() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: OverlayContentView())

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.midX - 120
            let y = frame.maxY - 64
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        return panel
    }
}

private struct OverlayContentView: View {
    @ObservedObject private var state = AppState.shared

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .shadow(color: .red.opacity(0.6), radius: 4)

            Text("Listening...")
                .font(.system(size: 13, weight: .medium))

            Text(state.formattedDuration)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)

            Button {
                NotificationCenter.default.post(name: .cancelRecording, object: nil)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}

extension Notification.Name {
    static let cancelRecording = Notification.Name("FlowVoice.cancelRecording")
}
