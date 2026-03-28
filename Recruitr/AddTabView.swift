import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct AddTabView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var isProcessing: Bool
    @Binding var processingStage: ProcessingStage?
    @Binding var isDone: Bool
    
    @State private var audioFiles: [URL] = []
    @State private var pdfFile: URL? = nil
    @State private var notes: String = ""
    @State private var name: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showPromptPicker: Bool = false
    @State private var selectedPromptIds: Set<String> = []
    @State private var pendingSubmitType: RecordType? = nil
    @FocusState private var focusedField: FocusedField?
    
    @State private var transcriptionMode: TranscriptionMode = AIConfiguration.shared.transcriptionMode
    private let addFieldMaxWidth: CGFloat = 470

    private enum FocusedField: Hashable {
        case name
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                fixedGridLayout(in: geometry.size)
                    .frame(minHeight: geometry.size.height, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDroppedProviders)
        .sheet(isPresented: $showError) {
            ErrorSheet(errorMessage: errorMessage, onDismiss: { showError = false })
        }
        .sheet(isPresented: $showPromptPicker) {
            PromptPickerView(
                selectedPromptIds: $selectedPromptIds,
                onConfirm: {
                    showPromptPicker = false
                    if let submitType = pendingSubmitType {
                        submit(type: submitType)
                        pendingSubmitType = nil
                    }
                },
                onCancel: {
                    showPromptPicker = false
                    selectedPromptIds = []
                    pendingSubmitType = nil
                }
            )
        }
    }

    private func fixedGridLayout(in size: CGSize) -> some View {
        let horizontalMargin: CGFloat = 28
        let verticalMargin: CGFloat = 28
        let columnSpacing: CGFloat = 18
        let rowSpacing: CGFloat = 18
        let headerSpacing: CGFloat = 18
        let availableWidth = max(size.width - (horizontalMargin * 2), 420)
        let idealCanvasWidth = (addFieldMaxWidth * 2) + columnSpacing
        let gridWidth = min(idealCanvasWidth, availableWidth)
        let columnWidth = min(addFieldMaxWidth, max(220, (gridWidth - columnSpacing) / 2))
        let compactCardHeight: CGFloat = 164
        let uploadCardHeight: CGFloat = 212
        let largeCardHeight: CGFloat = 342

        return VStack(spacing: headerSpacing) {
            header
                .frame(width: gridWidth, alignment: .leading)

            HStack(alignment: .top, spacing: columnSpacing) {
                VStack(spacing: rowSpacing) {
                    documentUploadSection
                        .frame(width: columnWidth, height: uploadCardHeight)

                    nameSection
                        .frame(width: columnWidth, height: compactCardHeight)

                    notesSection
                        .frame(width: columnWidth, height: largeCardHeight)
                }

                VStack(spacing: rowSpacing) {
                    audioUploadSection
                        .frame(width: columnWidth, height: uploadCardHeight)

                    readySection(buttonsVertical: true)
                        .frame(width: columnWidth, height: largeCardHeight)

                    transcriptionSection
                        .frame(width: columnWidth, height: compactCardHeight)
                }
            }
            .frame(width: gridWidth)
        }
        .padding(.horizontal, horizontalMargin)
        .padding(.vertical, verticalMargin)
        .frame(maxWidth: .infinity, minHeight: size.height, alignment: .center)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.blue500.opacity(0.2),
                        DesignSystem.Colors.sky500.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignSystem.Colors.blue500.opacity(0.9))
            }
            .frame(width: 52, height: 52)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(DesignSystem.Colors.blue500.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Add New Record")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text("Upload audio or a document, add context, then let AI build a clean recruiting record.")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var audioUploadSection: some View {
        SurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                FormSectionHeader("Audio Files", subtitle: "Supports MP3, WAV, and M4A. You can add multiple files.")

                FileUploaderCard(
                    fileType: .audio,
                    files: audioFiles,
                    onFilesSelected: { urls in
                        audioFiles.append(contentsOf: urls)
                    },
                    onRemoveFile: { index in
                        audioFiles.remove(at: index)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var documentUploadSection: some View {
        SurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                FormSectionHeader("Document", subtitle: "Attach one PDF or DOCX file to give the model more context.")

                FileUploaderCard(
                    fileType: .pdf,
                    files: pdfFile.map { [$0] } ?? [],
                    onFilesSelected: { urls in
                        if let first = urls.first {
                            pdfFile = first
                        }
                    },
                    onRemoveFile: { _ in
                        pdfFile = nil
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var transcriptionSection: some View {
        SurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                FormSectionHeader("Transcription Mode", subtitle: "Cloud is faster to set up. Local keeps transcription on-device when the model is bundled.")

                Picker("", selection: $transcriptionMode) {
                    ForEach(TranscriptionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: transcriptionMode) { newMode in
                    AIConfiguration.shared.transcriptionMode = newMode
                }
            }
        }
    }

    private var nameSection: some View {
        SurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                FormSectionHeader("Name", subtitle: "Use the candidate or client name you want saved to the record.")

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Enter name", text: $name)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .name)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(.vertical, 4)

                    Capsule()
                        .fill(focusedField == .name ? DesignSystem.Colors.blue500.opacity(0.8) : DesignSystem.Colors.inputBorder)
                        .frame(height: 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = .name
            }
        }
    }

    private var notesSection: some View {
        SurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                FormSectionHeader("Additional Notes", subtitle: "Optional context, call notes, or recruiter observations.")
                MarkdownTextView(text: $notes, placeholder: "Enter notes about this record…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func readySection(buttonsVertical: Bool) -> some View {
        SurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                FormSectionHeader("Ready to Create", subtitle: "See the current intake at a glance, then save it as a client or candidate record.")

                VStack(alignment: .leading, spacing: 12) {
                    intakeOverviewRow(title: "Audio files", value: audioFiles.isEmpty ? "None added yet" : "\(audioFiles.count) attached")
                    intakeOverviewRow(title: "Document", value: pdfFile?.lastPathComponent ?? "No document attached")
                    intakeOverviewRow(title: "Notes", value: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No notes yet" : "Notes added")
                    intakeOverviewRow(title: "Name", value: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not entered" : name.trimmingCharacters(in: .whitespacesAndNewlines))
                }

                Spacer(minLength: 0)

                if buttonsVertical {
                    VStack(spacing: 12) {
                        submitButton(title: "Create Client", gradient: RecordTypeAccent.client.gradient) {
                            submit(type: .client)
                        }

                        submitButton(title: "Create Candidate", gradient: RecordTypeAccent.candidate.gradient) {
                            showPromptPicker = true
                            pendingSubmitType = .candidate
                        }
                    }
                } else {
                    HStack(spacing: 16) {
                        submitButton(title: "Create Client", gradient: RecordTypeAccent.client.gradient) {
                            submit(type: .client)
                        }

                        submitButton(title: "Create Candidate", gradient: RecordTypeAccent.candidate.gradient) {
                            showPromptPicker = true
                            pendingSubmitType = .candidate
                        }
                    }
                }
            }
        }
    }

    private func intakeOverviewRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 82, alignment: .leading)

            Text(value)
                .font(.system(size: 13))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func submitButton(title: String, gradient: LinearGradient, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.65 : 1)
    }
    
    private func handleDroppedFiles(_ urls: [URL]) {
        for url in urls {
            let fileExtension = url.pathExtension.lowercased()
            
            if FileType.audio.supportedExtensions.contains(fileExtension) {
                audioFiles.append(url)
            }
            else if FileType.pdf.supportedExtensions.contains(fileExtension) {
                pdfFile = url
            }
        }
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        var didAcceptProvider = false

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            didAcceptProvider = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = droppedFileURL(from: item) else { return }
                DispatchQueue.main.async {
                    handleDroppedFiles([url])
                }
            }
        }

        return didAcceptProvider
    }

    private func droppedFileURL(from item: NSSecureCoding?) -> URL? {
        if let data = item as? Data {
            return NSURL(
                absoluteURLWithDataRepresentation: data,
                relativeTo: nil
            ) as URL?
        }

        if let url = item as? URL {
            return url
        }

        if let nsURL = item as? NSURL {
            return nsURL as URL
        }

        return nil
    }
    
    private func submit(type: RecordType) {
        guard !audioFiles.isEmpty || pdfFile != nil else {
            errorMessage = "Please upload at least one audio or PDF file."
            showError = true
            return
        }
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a name."
            showError = true
            return
        }
        
        isProcessing = true
        processingStage = ProcessingStage(title: "Preparing record", detail: "Checking your files and notes")
        Task {
            do {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let processedInput = try await processInputFiles()
                processingStage = ProcessingStage(title: "Loading prompts", detail: "Preparing the extraction fields for this record")

                let availablePrompts = try await loadPrompts(for: type)
                let promptsToUse = RecordProcessingSupport.promptsToUse(
                    for: type,
                    candidatePrompts: type == .candidate ? availablePrompts : [],
                    clientPrompts: type == .client ? availablePrompts : [],
                    selectedPromptIds: selectedPromptIds
                )

                guard !promptsToUse.isEmpty else {
                    throw NSError(domain: "AddTabView", code: 4, userInfo: [NSLocalizedDescriptionKey: "No prompts available. Please add prompts in the Prompt Management section."])
                }

                let extractedFields = try await extractFields(
                    using: promptsToUse,
                    baseContext: processedInput.context,
                    name: trimmedName
                )

                let record = Record(
                    name: trimmedName,
                    type: type.rawValue,
                    fields: extractedFields,
                    userNotes: notes,
                    transcript: processedInput.transcript,
                    pdfText: processedInput.pdfText,
                    promptIdsUsed: type == .candidate ? promptsToUse.compactMap(\.id) : nil
                )

                processingStage = ProcessingStage(title: "Saving record", detail: "Writing the finished record to Appwrite", progress: 0.95)
                await MainActor.run {
                    dataManager.beginSavingRecords()
                }

                do {
                    let savedRecord = try await appwriteCreateRecord(
                        record,
                        databaseId: appwriteDatabaseId,
                        collectionId: appwriteCollectionId
                    )

                    await MainActor.run {
                        dataManager.addRecord(savedRecord)
                        isProcessing = false
                        processingStage = nil
                        audioFiles = []
                        pdfFile = nil
                        notes = ""
                        name = ""
                        selectedPromptIds = []
                        isDone = true
                    }

                    WebhookService.shared.sendNewRecordNotification(record: savedRecord)
                } catch {
                    await MainActor.run {
                        isProcessing = false
                        processingStage = nil
                        errorMessage = "Failed to save record: \(error.localizedDescription)"
                        showError = true
                    }
                }

                await MainActor.run {
                    dataManager.finishSavingRecords()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    processingStage = nil
                    errorMessage = error.localizedDescription
                    showError = true
                    dataManager.finishSavingRecords()
                }
            }
        }
    }

    private func processInputFiles() async throws -> (context: String, transcript: String?, pdfText: String?) {
        var context = notes
        var transcript: String?
        var pdfExtractedText: String?
        var allTranscripts: [String] = []
        let totalStages = max(audioFiles.count + (pdfFile != nil ? 1 : 0), 1)

        for (index, audio) in audioFiles.enumerated() {
            processingStage = ProcessingStage(
                title: "Transcribing audio",
                detail: "File \(index + 1) of \(audioFiles.count): \(audio.lastPathComponent)",
                progress: Double(index) / Double(totalStages),
                currentStep: index + 1,
                totalSteps: totalStages
            )
            let singleTranscript = try await AudioTranscriber.shared.transcribeAudio(url: audio)
            allTranscripts.append(singleTranscript)
        }

        if !allTranscripts.isEmpty {
            transcript = allTranscripts.joined(separator: "\n\n--- Next Audio File ---\n\n")
            context += context.isEmpty ? transcript ?? "" : "\n\(transcript ?? "")"
        }

        if let pdf = pdfFile {
            processingStage = ProcessingStage(
                title: "Extracting document text",
                detail: pdf.lastPathComponent,
                progress: Double(audioFiles.count) / Double(totalStages),
                currentStep: min(audioFiles.count + 1, totalStages),
                totalSteps: totalStages
            )
            pdfExtractedText = try await DocumentTextExtractor.shared.extractText(from: pdf)
            if let pdfExtractedText, !pdfExtractedText.isEmpty {
                context += context.isEmpty ? pdfExtractedText : "\n\(pdfExtractedText)"
            }
        }

        return (context, transcript, pdfExtractedText)
    }

    private func loadPrompts(for type: RecordType) async throws -> [PromptTemplate] {
        let currentPrompts = type == .candidate ? dataManager.candidatePrompts : dataManager.clientPrompts
        if !currentPrompts.isEmpty {
            return currentPrompts
        }

        await dataManager.refreshPrompts()
        let refreshedPrompts = type == .candidate ? dataManager.candidatePrompts : dataManager.clientPrompts

        guard !refreshedPrompts.isEmpty else {
            throw NSError(
                domain: "AddTabView",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "No prompts found for \(type.rawValue) type. Please add prompts in the Prompt Management section."]
            )
        }

        return refreshedPrompts
    }

    private func extractFields(using prompts: [PromptTemplate], baseContext: String, name: String) async throws -> [RecordField] {
        var fields: [RecordField] = []
        var encounteredFieldError = false

        for (index, promptTemplate) in prompts.enumerated() {
            let prompt = FieldPrompt(field: promptTemplate.field, prompt: promptTemplate.prompt)
            processingStage = ProcessingStage(
                title: "Running AI prompts",
                detail: "Processing \(prompt.field) (\(index + 1) of \(prompts.count))",
                progress: Double(index + 1) / Double(max(prompts.count, 1)),
                currentStep: index + 1,
                totalSteps: prompts.count
            )

            do {
                let result = try await UnifiedFieldExtractor.shared.extractSingleField(
                    prompt: prompt,
                    context: RecordProcessingSupport.combinedContext(baseContext: baseContext, extractedFields: fields),
                    name: name
                )
                fields.append(RecordField(key: prompt.field, value: result))
            } catch {
                if isOpenAIQuotaError(error) {
                    throw NSError(
                        domain: "AddTabView",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "OpenAI quota exceeded. Please check your billing details or upgrade your plan."]
                    )
                }

                encounteredFieldError = true
                AppLogger.ai.error("Failed to process prompt \(prompt.field, privacy: .public): \(error.localizedDescription)")
                fields.append(RecordField(key: prompt.field, value: "[Error: \(error.localizedDescription)]"))
            }
        }

        if encounteredFieldError {
            let providerName = AIConfiguration.shared.selectedProvider.displayName
            throw NSError(
                domain: "AddTabView",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "\(providerName) did not return a valid response for all fields. Please try again."]
            )
        }

        return fields
    }

    private func isOpenAIQuotaError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == "OpenAIFieldExtractor", nsError.code == 429 else {
            return false
        }

        let description = nsError.userInfo[NSLocalizedDescriptionKey] as? String ?? ""
        return description.contains("insufficient_quota")
    }
}

// Helper views
struct FileUploaderCard: View {
    let fileType: FileType
    let files: [URL]
    let onFilesSelected: ([URL]) -> Void
    let onRemoveFile: (Int) -> Void
    
    @State private var showPicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: { showPicker = true }) {
                VStack(spacing: 8) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.blue500.opacity(0.1),
                                DesignSystem.Colors.sky500.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: fileType.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.blue500.opacity(0.7))
                    }
                    .frame(width: 36, height: 36)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DesignSystem.Colors.blue500.opacity(0.2), lineWidth: 1)
                    )
                    
                    VStack(spacing: 2) {
                        Text(fileType.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text(fileType.instruction)
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(fileType.supportedExtensions.map { $0.uppercased() }.sorted().joined(separator: ", "))
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 104)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(DesignSystem.Colors.cardBorder, style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.02))
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if !files.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(files.enumerated()), id: \.offset) { index, url in
                            HStack(spacing: 12) {
                                ZStack {
                                    LinearGradient(
                                        colors: [
                                            DesignSystem.Colors.blue500.opacity(0.1),
                                            DesignSystem.Colors.sky500.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.blue500.opacity(0.7))
                                }
                                .frame(width: 32, height: 32)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(DesignSystem.Colors.blue500.opacity(0.2), lineWidth: 1)
                                )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .lineLimit(1)

                                    Text(FileMetadataFormatter.description(for: url, fileType: fileType))
                                        .font(.system(size: 11))
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Button(action: { onRemoveFile(index) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                        .frame(width: 32, height: 32)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(10)
                            .background(DesignSystem.Colors.cardBackground)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                            )
                        }
                    }
                }
                .frame(maxHeight: fileType == .audio ? 74 : 64)
            }
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: fileType.allowedTypes, allowsMultipleSelection: fileType == .audio) { result in
            switch result {
            case .success(let urls):
                var validURLs: [URL] = []
                for url in urls {
                    let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if hasSecurityScopedAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    if hasSecurityScopedAccess || url.isFileURL {
                        let fileExtension = url.pathExtension.lowercased()
                        
                        if fileType.supportedExtensions.contains(fileExtension) {
                            validURLs.append(url)
                        } else {
                            errorMessage = "Unsupported file type: \(fileExtension.uppercased()). Please select a \(fileType == .pdf ? "PDF or DOCX" : "MP3, WAV, or M4A") file."
                            showError = true
                        }
                    } else {
                        errorMessage = "Could not access the selected file. Please make sure the file exists and you have permission to access it."
                        showError = true
                    }
                }
                if !validURLs.isEmpty {
                    onFilesSelected(validURLs)
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

private enum FileMetadataFormatter {
    static func description(for url: URL, fileType: FileType) -> String {
        var components: [String] = []

        let extensionText = url.pathExtension.uppercased()
        if !extensionText.isEmpty {
            components.append(extensionText)
        }

        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            components.append(formattedSize)
        }

        if fileType == .audio {
            let duration = AVURLAsset(url: url).duration.seconds
            if duration.isFinite && duration > 0 {
                components.append(formatDuration(duration))
            }
        }

        return components.joined(separator: " • ")
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        FormInputFieldStyle()._body(configuration: configuration)
    }
}

struct ErrorSheet: View {
    let errorMessage: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Error")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.red)
            
            Text(errorMessage)
                .multilineTextAlignment(.center)
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.horizontal)
            
            Button("OK", action: onDismiss)
                .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(DesignSystem.Colors.buttonBlueGradient)
                .cornerRadius(10)
                .padding(.top)
        }
        .padding(32)
        .frame(maxWidth: 400, maxHeight: 300)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.backgroundGradientMiddle,
                    DesignSystem.Colors.backgroundGradientStart
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct PromptPickerView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var selectedPromptIds: Set<String>
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var searchText: String = ""
    @State private var selectedBundleId: String? = nil
    @State private var selectionMode: SelectionMode = .manual
    
    enum SelectionMode {
        case manual
        case bundle
    }
    
    private var candidatePrompts: [PromptTemplate] {
        dataManager.candidatePrompts
    }

    private var bundles: [PromptBundle] {
        dataManager.candidatePromptBundles
    }
    
    private var filteredPrompts: [PromptTemplate] {
        if searchText.isEmpty {
            return candidatePrompts
        } else {
            return candidatePrompts.filter { prompt in
                prompt.field.localizedCaseInsensitiveContains(searchText) ||
                prompt.prompt.localizedCaseInsensitiveContains(searchText) ||
                prompt.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    // Group prompts by tags for easier selection
    private var promptsByTag: [String: [PromptTemplate]] {
        var grouped: [String: [PromptTemplate]] = [:]
        for prompt in filteredPrompts {
            if prompt.tags.isEmpty {
                grouped["Other", default: []].append(prompt)
            } else {
                for tag in prompt.tags {
                    grouped[tag, default: []].append(prompt)
                }
            }
        }
        return grouped
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Select Prompts")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Button("Confirm") {
                        onConfirm()
                    }
                    .disabled(selectedPromptIds.isEmpty)
                    .foregroundColor(selectedPromptIds.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.blue500)
                    .font(.system(size: 14, weight: .semibold))
                }
                .padding()
                .background(DesignSystem.Colors.cardBackground)
            
            Divider()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                TextField("Search prompts...", text: $searchText)
                    .textFieldStyle(SearchFieldStyle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .padding()
            .background(DesignSystem.Colors.cardBackground)
            
            Divider()
            
            // Selection Mode Toggle
            HStack(spacing: 12) {
                Button(action: { 
                    selectionMode = .bundle
                    ensureBundlesLoadedIfNeeded()
                }) {
                    Text("Use Bundle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selectionMode == .bundle ? .white : DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if selectionMode == .bundle {
                                    DesignSystem.Colors.buttonSkyGradient
                                } else {
                                    DesignSystem.Colors.cardBackground
                                }
                            }
                        )
                        .cornerRadius(DesignSystem.Radius.sm)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { selectionMode = .manual }) {
                    Text("Manual Selection")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selectionMode == .manual ? .white : DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if selectionMode == .manual {
                                    DesignSystem.Colors.buttonBlueGradient
                                } else {
                                    DesignSystem.Colors.cardBackground
                                }
                            }
                        )
                        .cornerRadius(DesignSystem.Radius.sm)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding()
            .background(DesignSystem.Colors.cardBackground)
            
            Divider()
            
            if selectionMode == .bundle {
                // Bundle Selection
                ZStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if dataManager.isLoadingBundles {
                                SectionLoadingView()
                                    .padding(.top, 40)
                            } else if bundles.isEmpty {
                                VStack(spacing: 8) {
                                    Text("No bundles available")
                                        .font(.headline)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    Text("Create bundles in Prompt Management")
                                        .font(.caption)
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            } else {
                                ForEach(bundles, id: \.id) { bundle in
                                    BundlePickerRow(
                                        bundle: bundle,
                                        candidatePrompts: candidatePrompts,
                                        isSelected: bundle.id == selectedBundleId,
                                        onSelect: {
                                            if selectedBundleId == bundle.id {
                                                selectedBundleId = nil
                                                selectedPromptIds = []
                                            } else {
                                                selectedBundleId = bundle.id
                                                selectedPromptIds = Set(bundle.promptIds)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                    .background(DesignSystem.Colors.backgroundGradientStart)
                }
            } else {
                // Quick actions
                HStack(spacing: 12) {
                    Button("Select All Enabled") {
                        selectedPromptIds = Set(candidatePrompts.filter { $0.enabledByDefault }.compactMap { $0.id })
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("Select All") {
                        selectedPromptIds = Set(candidatePrompts.compactMap { $0.id })
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("Clear All") {
                        selectedPromptIds = []
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Spacer()
                    
                    Text("\(selectedPromptIds.count) selected")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding()
                .background(DesignSystem.Colors.cardBackground)
                
                Divider()
                
                // Prompt list
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if filteredPrompts.isEmpty {
                            VStack(spacing: 8) {
                                Text("No prompts found")
                                    .font(.headline)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text("Try adjusting your search or add prompts in Prompt Management")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(Array(promptsByTag.keys.sorted()), id: \.self) { tag in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(tag)
                                        .font(.headline)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .padding(.horizontal)
                                        .padding(.top, 8)
                                    
                                    ForEach(promptsByTag[tag] ?? [], id: \.id) { prompt in
                                        PromptPickerRow(
                                            prompt: prompt,
                                            isSelected: prompt.id != nil && selectedPromptIds.contains(prompt.id!),
                                            onToggle: {
                                                if let id = prompt.id {
                                                    if selectedPromptIds.contains(id) {
                                                        selectedPromptIds.remove(id)
                                                    } else {
                                                        selectedPromptIds.insert(id)
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(DesignSystem.Colors.backgroundGradientStart)
            }
            }
            .frame(minWidth: 640, idealWidth: 860, maxWidth: 980, minHeight: 560, idealHeight: 660, maxHeight: 820)
            .background(DesignSystem.Colors.backgroundGradientStart)
            
            // Show loading overlay if prompts are loading
            if dataManager.isLoadingPrompts {
                LoadingOverlay(message: "Loading prompts...")
            }
        }
        .onAppear {
            // Initialize with enabledByDefault prompts
            if selectedPromptIds.isEmpty && !candidatePrompts.isEmpty {
                selectedPromptIds = Set(candidatePrompts.filter { $0.enabledByDefault }.compactMap { $0.id })
            }
        }
    }
    
    private func ensureBundlesLoadedIfNeeded() {
        guard bundles.isEmpty && !dataManager.isLoadingBundles else {
            return
        }

        Task {
            await dataManager.refreshPromptBundles()
            if let lastError = dataManager.lastError, lastError.contains("bundles") {
                AppLogger.data.error("Failed to load candidate bundles: \(lastError)")
            }
        }
    }
}


struct PromptPickerRow: View {
    let prompt: PromptTemplate
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? DesignSystem.Colors.blue500 : DesignSystem.Colors.textSecondary)
                    .font(.system(size: 20))
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(prompt.field)
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    if !prompt.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(prompt.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(DesignSystem.Colors.blue500.opacity(0.2))
                                    .foregroundColor(DesignSystem.Colors.blue500)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    
                    if !prompt.enabledByDefault {
                        Text("(disabled by default)")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .italic()
                    }
                }
                
                Text(prompt.prompt)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(isSelected ? DesignSystem.Colors.blue500.opacity(0.1) : DesignSystem.Colors.cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? DesignSystem.Colors.blue500 : DesignSystem.Colors.cardBorder, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct BundlePickerRow: View {
    let bundle: PromptBundle
    let candidatePrompts: [PromptTemplate]
    let isSelected: Bool
    let onSelect: () -> Void

    private let accent = RecordTypeAccent.candidate
    
    private var promptNames: [String] {
        bundle.promptIds.compactMap { id in
            candidatePrompts.first { $0.id == id }?.field
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? accent.tint : DesignSystem.Colors.textSecondary)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "square.stack.fill")
                            .font(.system(size: 14))
                            .foregroundColor(accent.tint)
                        Text(bundle.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    
                    if !promptNames.isEmpty {
                        Text("\(promptNames.count) prompt\(promptNames.count == 1 ? "" : "s"): \(promptNames.prefix(3).joined(separator: ", "))\(promptNames.count > 3 ? "..." : "")")
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(isSelected ? accent.subtleFill : DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .stroke(isSelected ? accent.tint : DesignSystem.Colors.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
