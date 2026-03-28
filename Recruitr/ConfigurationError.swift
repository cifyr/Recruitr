import Foundation

enum ConfigurationError: LocalizedError {
    case missingGeminiPlist
    case missingGeminiAPIKey
    case placeholderGeminiAPIKey
    case missingWhisperModel

    var errorDescription: String? {
        switch self {
        case .missingGeminiPlist:
            return "The Gemini configuration file is missing from the app bundle."
        case .missingGeminiAPIKey:
            return "The Gemini API key is missing from GenerativeAI-Info.plist."
        case .placeholderGeminiAPIKey:
            return "The bundled Gemini API key is still a placeholder value."
        case .missingWhisperModel:
            return "The local Whisper model is missing from the app bundle. Switch to Cloud transcription or add the model file."
        }
    }
}
