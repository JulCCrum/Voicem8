import AVFoundation

final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    func start() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("flowvoice_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.isMeteringEnabled = true
        rec.record()
        recorder = rec
        fileURL = url
    }

    @discardableResult
    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        let url = fileURL
        fileURL = nil
        return url
    }

    /// Returns normalized audio level (0.0–1.0)
    func currentLevel() -> Float {
        guard let recorder = recorder else { return 0 }
        recorder.updateMeters()
        let dB = recorder.averagePower(forChannel: 0) // -160...0
        let minDB: Float = -40
        let clamped = max(dB, minDB)
        let linear = (clamped - minDB) / -minDB // normalize to 0...1
        return sqrt(linear) // square root curve to amplify quiet sounds
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        fileURL = nil
    }
}
