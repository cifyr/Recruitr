import SwiftUI
import UniformTypeIdentifiers

enum FileType {
    case audio, pdf

    var supportedExtensions: Set<String> {
        switch self {
        case .audio:
            return ["mp3", "wav", "m4a"]
        case .pdf:
            return ["pdf", "docx"]
        }
    }

    var allowedTypes: [UTType] {
        switch self {
        case .audio:
            if let m4aType = UTType.types(tag: "m4a", tagClass: .filenameExtension, conformingTo: .audio).first {
                return [.mp3, .wav, m4aType]
            } else {
                return [.mp3, .wav, UTType(importedAs: "com.apple.m4a-audio")]
            }
        case .pdf:
            // Properly handle both PDF and DOCX file types
            let docxType = UTType(filenameExtension: "docx") ?? UTType(importedAs: "org.openxmlformats.wordprocessingml.document")
            return [.pdf, docxType].compactMap { $0 }
        }
    }
    var label: String {
        switch self {
        case .audio: return "Upload Audio File"
        case .pdf: return "Upload Document"
        }
    }
    var instruction: String {
        switch self {
        case .audio: return "Click to select"
        case .pdf: return "Click to select PDF or DOCX"
        }
    }
    var icon: String {
        switch self {
        case .audio: return "music.note"
        case .pdf: return "doc.richtext"
        }
    }
}

struct FileUploader: View {
    let fileType: FileType
    @Binding var fileURL: URL?
    @State private var showPicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: { showPicker = true }) {
                ZStack {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 64, height: 64)
                    Image(systemName: fileType.icon)
                        .renderingMode(.template) // Force monochrome rendering
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
            }.buttonStyle(PlainButtonStyle())
            Text(fileType.label)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            if fileType == .audio {
                Text("Supports: MP3, WAV, M4A")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else if fileType == .pdf {
                Text("Supports: PDF, DOCX")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Text(fileType.instruction)
                .font(.subheadline)
                .foregroundColor(.gray)
            if let url = fileURL {
                HStack {
                    Text(url.lastPathComponent)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { fileURL = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.sRGB, red: 0.13, green: 0.15, blue: 0.19, opacity: 0.8))
        .cornerRadius(16)
        .fileImporter(isPresented: $showPicker, allowedContentTypes: fileType.allowedTypes, allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if hasSecurityScopedAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    if hasSecurityScopedAccess || url.isFileURL {
                        let fileExtension = url.pathExtension.lowercased()
                        
                        if fileType.supportedExtensions.contains(fileExtension) {
                            fileURL = url
                        } else {
                            errorMessage = "Unsupported file type: \(fileExtension.uppercased()). Please select a \(fileType == .pdf ? "PDF or DOCX" : "MP3, WAV, or M4A") file."
                            showError = true
                        }
                    } else {
                        errorMessage = "Could not access the selected file. Please make sure the file exists and you have permission to access it."
                        showError = true
                    }
                }
            case .failure(let error):
                errorMessage = "Failed to import file: \(error.localizedDescription)"
                showError = true
            }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
} 
