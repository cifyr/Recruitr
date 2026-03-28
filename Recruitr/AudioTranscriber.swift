import Foundation

final class AudioTranscriber {
    static let shared = AudioTranscriber()

    private init() {}

    func transcribeAudio(url: URL) async throws -> String {
        DemoEnvironment.demoTranscript(for: url, mode: AIConfiguration.shared.transcriptionMode)
    }
}
