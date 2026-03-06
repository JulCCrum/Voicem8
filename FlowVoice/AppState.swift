import Foundation
import Combine

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var recordingDuration: TimeInterval = 0

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "groqAPIKey") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "groqAPIKey")
            objectWillChange.send()
        }
    }

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private init() {}
}
