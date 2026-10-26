import SwiftUI

enum OverlayPanel {
    static func create() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: OverlayContentView())

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.midX - 150
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
            // Animated waveform bars
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.red)
                        .frame(width: 3, height: max(4, CGFloat(state.audioLevels[i]) * 28))
                        .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: state.audioLevels[i])
                }
            }
            .frame(height: 20)

            Text("Listening...")
                .font(.system(size: 13, weight: .medium))
                .fixedSize()

            Text(state.formattedDuration)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize()

            Button {
                NotificationCenter.default.post(name: .cancelRecording, object: nil)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .fixedSize()
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}

extension Notification.Name {
    static let cancelRecording = Notification.Name("FlowVoice.cancelRecording")
}
