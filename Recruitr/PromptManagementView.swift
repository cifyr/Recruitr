import SwiftUI

struct PromptManagementView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAddPrompt = false
    @State private var showAddBundle = false
    @State private var selectedPrompt: PromptTemplate? = nil
    @State private var editingPrompt: PromptTemplate? = nil // Preserved prompt for editing
    @State private var selectedBundle: PromptBundle? = nil
    @State private var isEditing = false
    @State private var isEditingBundle = false
    @State private var isSavingPrompt = false
    @State private var expandedClient = true
    @State private var expandedCandidate = true
    @State private var expandedBundles = true
    
    // Computed properties that use dataManager
    private var clientPrompts: [PromptTemplate] {
        dataManager.clientPrompts
    }
    
    private var candidatePrompts: [PromptTemplate] {
        dataManager.candidatePrompts
    }

    private var bundles: [PromptBundle] {
        dataManager.promptBundles
    }
    
    var body: some View {
        GeometryReader { geometry in
            let widthCategory = ResponsiveWidthCategory(width: geometry.size.width)

            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        if widthCategory == .wide {
                            HStack(alignment: .top, spacing: 18) {
                                promptHeader
                                providerUsageCard
                                    .frame(maxWidth: 360)
                            }
                        } else {
                            VStack(spacing: 18) {
                                promptHeader
                                providerUsageCard
                            }
                        }

                        VStack(spacing: 24) {
                    // Bundles Section
                    PromptBundlesSection(
                        bundles: bundles,
                        candidatePrompts: candidatePrompts,
                        onDelete: { bundle in
                            deleteBundle(bundle)
                        },
                        onEdit: { bundle in
                            selectedBundle = bundle
                            isEditingBundle = true
                            showAddBundle = true
                        },
                        expanded: $expandedBundles,
                        isLoading: dataManager.isLoadingBundles
                    )
                    
                    // Client Prompts Section
                    ModernPromptSection(
                        title: "Client Prompts",
                        prompts: clientPrompts,
                        onDelete: { prompt in
                            deletePrompt(prompt)
                        },
                        onEdit: { prompt in
                            editingPrompt = prompt
                            selectedPrompt = prompt
                            isEditing = true
                            showAddPrompt = true
                        },
                        expanded: $expandedClient
                    )
                    .environmentObject(dataManager)
                    
                    // Candidate Prompts Section
                    ModernPromptSection(
                        title: "Candidate Prompts",
                        prompts: candidatePrompts,
                        onDelete: { prompt in
                            deletePrompt(prompt)
                        },
                        onEdit: { prompt in
                            editingPrompt = prompt
                            selectedPrompt = prompt
                            isEditing = true
                            showAddPrompt = true
                        },
                        expanded: $expandedCandidate
                    )
                    .environmentObject(dataManager)
                }
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, widthCategory == .wide ? 40 : 24)
                    .padding(.top, 32)
                    .frame(maxWidth: 1280)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if dataManager.isLoadingPrompts || dataManager.isLoadingBundles {
                    LoadingOverlay(message: dataManager.isLoadingPrompts ? "Loading prompts..." : "Loading bundles...")
                }
            }
        }
        .onAppear {
            // If prompts are empty and not currently loading, wait for initial load
            if dataManager.prompts.isEmpty && !dataManager.isLoadingPrompts {
                Task {
                    await dataManager.refreshPrompts()
                }
            }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showAddPrompt) {
            Group {
                // Only show loading if we're editing an existing prompt and it's not available yet
                // For new prompts, we don't need to wait for anything
                let isNewPrompt = (editingPrompt == nil && selectedPrompt == nil)
                
                if !isNewPrompt && (dataManager.isLoadingPrompts || dataManager.prompts.isEmpty) {
                    // Show loading state in sheet only when editing and data isn't ready
                    ZStack {
                        DesignSystem.Colors.backgroundGradientStart
                        LoadingOverlay(message: "Loading prompt data...")
                    }
                    .frame(minWidth: 700, idealWidth: 920, maxWidth: 1160, minHeight: 620, idealHeight: 760, maxHeight: 900)
                    .task {
                        // Wait for prompts to load before showing content
                        if dataManager.prompts.isEmpty {
                            await dataManager.refreshPrompts()
                        }
                    }
                } else {
                    // Show edit view immediately for new prompts, or when data is ready for editing
                    ModernPromptEditView(
                        prompt: editingPrompt ?? selectedPrompt,
                        isSaving: isSavingPrompt,
                        onSave: { newPrompt in
                            Task {
                                await MainActor.run {
                                    dataManager.beginSavingPrompts()
                                    isSavingPrompt = true
                                }
                                var success = false
                                if isEditing {
                                    success = await updatePromptAsync(newPrompt)
                                } else {
                                    success = await addPromptAsync(newPrompt)
                                }
                                await MainActor.run {
                                    dataManager.finishSavingPrompts()
                                    isSavingPrompt = false
                                    if success {
                                        isEditing = false
                                        selectedPrompt = nil
                                        editingPrompt = nil
                                        showAddPrompt = false
                                    }
                                }
                            }
                        },
                        onCancel: {
                            isEditing = false
                            selectedPrompt = nil
                            editingPrompt = nil
                            showAddPrompt = false
                        }
                    )
                }
            }
        }
        .onChange(of: showAddPrompt) { isShowing in
            if !isShowing {
                // Reset state when sheet is dismissed
                isEditing = false
                selectedPrompt = nil
                editingPrompt = nil
            }
        }
        .sheet(isPresented: $showAddBundle) {
            Group {
                if dataManager.isLoadingPrompts || dataManager.prompts.isEmpty {
                    // Show loading state in sheet
                    ZStack {
                        DesignSystem.Colors.backgroundGradientStart
                            LoadingOverlay(message: "Loading prompt data...")
                    }
                    .frame(minWidth: 700, idealWidth: 920, maxWidth: 1160, minHeight: 620, idealHeight: 760, maxHeight: 900)
                    .task {
                        // Wait for prompts to load before showing content
                        if dataManager.prompts.isEmpty {
                            await dataManager.refreshPrompts()
                        }
                    }
                } else {
                    BundleEditView(
                        bundle: selectedBundle,
                        candidatePrompts: candidatePrompts,
                        onSave: { newBundle in
                            if isEditingBundle {
                                updateBundle(newBundle)
                            } else {
                                addBundle(newBundle)
                            }
                            isEditingBundle = false
                            selectedBundle = nil
                            showAddBundle = false
                        },
                        onCancel: {
                            isEditingBundle = false
                            selectedBundle = nil
                            showAddBundle = false
                        }
                    )
                }
            }
        }
    }

    private var promptHeader: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.blue500.opacity(0.2),
                                DesignSystem.Colors.sky500.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignSystem.Colors.blue500.opacity(0.85))
                    }
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .stroke(DesignSystem.Colors.blue500.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Prompt Management")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("Manage prompts, bundles, defaults, and provider visibility for AI extraction.")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    StatusPill(text: AIConfiguration.shared.selectedProvider.displayName, tint: DesignSystem.Colors.blue500)
                    StatusPill(text: AIConfiguration.shared.transcriptionMode.displayName, tint: DesignSystem.Colors.sky500)
                    Spacer()
                }

                HStack(spacing: 12) {
                    Button(action: { showAddBundle = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.stack.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text("New Bundle")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(DesignSystem.Colors.buttonSkyGradient)
                        .cornerRadius(DesignSystem.Radius.sm)
                    }
                    .buttonStyle(.plain)

                    Button(action: refreshBundles) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                            Text("Refresh Bundles")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(DesignSystem.Colors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(DesignSystem.Radius.sm)
                    }
                    .buttonStyle(.plain)
                    .disabled(dataManager.isLoadingBundles)

                    Button(action: {
                        editingPrompt = nil
                        selectedPrompt = nil
                        isEditing = false
                        showAddPrompt = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .medium))
                            Text("New Prompt")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(DesignSystem.Colors.buttonBlueGradient)
                        .cornerRadius(DesignSystem.Radius.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var providerUsageCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Provider Setup")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("The prompt editor will use the configured provider and model below.")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    UsageMetricTile(label: "Provider", value: AIConfiguration.shared.selectedProvider.displayName)
                    UsageMetricTile(
                        label: "Model",
                        value: AIConfiguration.shared.selectedProvider == .openai ? AIConfiguration.shared.openaiModel : "gemini-2.0-flash-lite"
                    )
                }

                UsageMetricTile(label: "Transcription", value: AIConfiguration.shared.transcriptionMode.displayName)

                Label("Live credit and usage totals are hidden for now so this page stays accurate and simple.", systemImage: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
    
    private func addPrompt(_ prompt: PromptTemplate) {
        Task {
            await addPromptAsync(prompt)
        }
    }
    
    private func addPromptAsync(_ prompt: PromptTemplate) async -> Bool {
        do {
            let createdPrompt = try await createPromptTemplateWithId(prompt)
            
            // Add to local cache immediately for instant UI update
            await MainActor.run {
                dataManager.addPrompt(createdPrompt)
                
                // Expand the relevant section so the new prompt is visible
                if createdPrompt.type == "client" {
                    expandedClient = true
                } else if createdPrompt.type == "candidate" {
                    expandedCandidate = true
                }
            }
            return true
        } catch {
            AppLogger.data.error("Failed to create prompt: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
            return false
        }
    }
    
    private func updatePrompt(_ prompt: PromptTemplate) {
        Task {
            await updatePromptAsync(prompt)
        }
    }
    
    private func updatePromptAsync(_ prompt: PromptTemplate) async -> Bool {
        guard let id = prompt.id else {
            await MainActor.run {
                errorMessage = "Cannot update prompt: missing ID"
                showError = true
            }
            return false
        }
        do {
            let updatedPrompt = try await updatePromptTemplate(prompt)
            await MainActor.run {
                dataManager.updatePrompt(updatedPrompt)
            }
            return true
        } catch {
            AppLogger.data.error("Failed to update prompt \(id, privacy: .public): \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
            return false
        }
    }
    
    private func deletePrompt(_ prompt: PromptTemplate) {
        Task {
            do {
                try await deletePromptTemplate(prompt)
                await MainActor.run {
                    dataManager.removePrompt(prompt)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func addBundle(_ bundle: PromptBundle) {
        Task {
            await MainActor.run {
                dataManager.beginSavingBundles()
            }
            do {
                let createdBundle = try await createPromptBundle(bundle)
                await MainActor.run {
                    dataManager.addPromptBundle(createdBundle)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run {
                dataManager.finishSavingBundles()
            }
        }
    }
    
    private func updateBundle(_ bundle: PromptBundle) {
        Task {
            await MainActor.run {
                dataManager.beginSavingBundles()
            }
            do {
                let updatedBundle = try await updatePromptBundle(bundle)
                await MainActor.run {
                    dataManager.updatePromptBundle(updatedBundle)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run {
                dataManager.finishSavingBundles()
            }
        }
    }
    
    private func deleteBundle(_ bundle: PromptBundle) {
        Task {
            await MainActor.run {
                dataManager.beginSavingBundles()
            }
            do {
                try await deletePromptBundle(bundle)
                await MainActor.run {
                    dataManager.removePromptBundle(bundle)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run {
                dataManager.finishSavingBundles()
            }
        }
    }

    private func refreshBundles() {
        Task {
            await dataManager.refreshPromptBundles()
            if let lastError = dataManager.lastError, lastError.contains("bundles") {
                await MainActor.run {
                    errorMessage = lastError
                    showError = true
                }
            }
        }
    }
}

struct ModernPromptSection: View {
    @EnvironmentObject var dataManager: DataManager
    let title: String
    let prompts: [PromptTemplate]
    let onDelete: (PromptTemplate) -> Void
    let onEdit: (PromptTemplate) -> Void
    @Binding var expanded: Bool

    private var accent: RecordTypeAccent {
        if let prompt = prompts.first {
            return prompt.accent
        }

        return title.localizedCaseInsensitiveContains("client") ? .client : .candidate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Button(action: { expanded.toggle() }) {
            HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accent.tint)
                            .frame(width: 6, height: 6)
                Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(accent.tint)
                    }
                Spacer()
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            if expanded {
                if dataManager.isLoadingPrompts {
                    SectionLoadingView()
                        .padding(.vertical, 24)
                } else if prompts.isEmpty {
                    VStack(spacing: 8) {
                    Text("No prompts yet")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        .italic()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 12) {
                    ForEach(prompts, id: \.id) { prompt in
                            ModernPromptRow(
                            prompt: prompt,
                                onDelete: { onDelete(prompt) },
                                onEdit: { onEdit(prompt) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }
}

struct ModernPromptRow: View {
    let prompt: PromptTemplate
    let onDelete: () -> Void
    let onEdit: () -> Void

    private var accent: RecordTypeAccent {
        prompt.accent
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                Text(prompt.field)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    if !prompt.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(prompt.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(accent.subtleFill)
                                    .foregroundColor(accent.tint)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    
                    if !prompt.enabledByDefault {
                        Text("(disabled)")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .italic()
                    }
                }
                
                Text(prompt.prompt)
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
            Button(action: onEdit) {
                Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(accent.tint)
                        .frame(width: 36, height: 36)
                        .background(accent.subtleFill)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.backgroundGradientMiddle.opacity(0.5))
        .cornerRadius(DesignSystem.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }
}

struct PromptBundlesSection: View {
    let bundles: [PromptBundle]
    let candidatePrompts: [PromptTemplate]
    let onDelete: (PromptBundle) -> Void
    let onEdit: (PromptBundle) -> Void
    @Binding var expanded: Bool
    let isLoading: Bool

    private let accent = RecordTypeAccent.candidate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { expanded.toggle() }) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accent.tint)
                            .frame(width: 6, height: 6)
                        Text("Prompt Bundles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(accent.tint)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            if expanded {
                if isLoading {
                    SectionLoadingView()
                        .padding(.vertical, 24)
                } else if bundles.isEmpty {
                    VStack(spacing: 8) {
                        Text("No bundles yet")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .italic()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 12) {
                        ForEach(bundles, id: \.id) { bundle in
                            BundleRow(
                                bundle: bundle,
                                candidatePrompts: candidatePrompts,
                                onDelete: { onDelete(bundle) },
                                onEdit: { onEdit(bundle) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }
}

struct BundleRow: View {
    let bundle: PromptBundle
    let candidatePrompts: [PromptTemplate]
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    private var promptNames: [String] {
        bundle.promptIds.compactMap { id in
            candidatePrompts.first { $0.id == id }?.field
        }
    }

    private let accent = RecordTypeAccent.candidate
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 14))
                        .foregroundColor(accent.tint)
                    Text(bundle.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                
                if !promptNames.isEmpty {
                    Text("\(promptNames.count) prompt\(promptNames.count == 1 ? "" : "s"): \(promptNames.joined(separator: ", "))")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                } else {
                    Text("No prompts in bundle")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .italic()
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(accent.tint)
                        .frame(width: 36, height: 36)
                        .background(accent.subtleFill)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
            Button(action: onDelete) {
                Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.backgroundGradientMiddle.opacity(0.5))
        .cornerRadius(DesignSystem.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }
}

// Modern Prompt Edit View
struct ModernPromptEditView: View {
    let prompt: PromptTemplate?
    var isSaving: Bool = false
    let onSave: (PromptTemplate) -> Void
    let onCancel: () -> Void
    
    @State private var field: String = ""
    @State private var promptText: String = ""
    @State private var type: String = "client"
    @State private var tags: String = ""
    @State private var enabledByDefault: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt == nil ? "Add New Prompt" : "Edit Prompt")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(prompt == nil ? "Create a new AI prompt template" : "Update prompt settings")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .font(.system(size: 15, weight: .medium))
                Button(action: {
                    savePrompt()
                }) {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isSaving ? "Saving..." : "Save")
                    }
                }
                .disabled(field.isEmpty || promptText.isEmpty || isSaving)
                .foregroundColor(.white)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if field.isEmpty || promptText.isEmpty || isSaving {
                                DesignSystem.Colors.textTertiary
                            } else {
                                DesignSystem.Colors.buttonBlueGradient
                            }
                        }
                    )
                    .cornerRadius(DesignSystem.Radius.sm)
                }
            }
            .padding(24)
            .background(DesignSystem.Colors.cardBackground)
            .overlay(
                Rectangle()
                    .fill(DesignSystem.Colors.cardBorder)
                    .frame(height: 1),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: 24) {
            // Type Selection
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.blue500, DesignSystem.Colors.sky500],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 6, height: 6)
                Text("Type")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                HStack(spacing: 0) {
                    Button(action: { type = "client" }) {
                        Text("Client")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(type == "client" ? .white : DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Group {
                                    if type == "client" {
                                        RecordTypeAccent.client.gradient
                                    } else {
                                        DesignSystem.Colors.cardBackground
                                    }
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { type = "candidate" }) {
                        Text("Candidate")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(type == "candidate" ? .white : DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Group {
                                    if type == "candidate" {
                                        RecordTypeAccent.candidate.gradient
                                    } else {
                                        DesignSystem.Colors.cardBackground
                                    }
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                        .cornerRadius(DesignSystem.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            
            // Field Name
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.blue500, DesignSystem.Colors.sky500],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 6, height: 6)
                            Text("Field Name *")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                TextField("Enter field name", text: $field)
                            .textFieldStyle(FormInputFieldStyle())
            }
                    .padding(.horizontal, 24)
            
            // Prompt Text
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.blue500, DesignSystem.Colors.sky500],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 6, height: 6)
                            Text("Prompt Text *")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                TextEditor(text: $promptText)
                            .frame(minHeight: 200)
                            .padding(12)
                            .background(DesignSystem.Colors.cardBackground)
                            .cornerRadius(DesignSystem.Radius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                            )
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    .padding(.horizontal, 24)
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.blue500, DesignSystem.Colors.sky500],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 6, height: 6)
                            Text("Tags")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        TextField("e.g., quick, deep, culture, technical", text: $tags)
                            .textFieldStyle(FormInputFieldStyle())
                    }
                    .padding(.horizontal, 24)
                    
                    // Enabled by Default Toggle
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.blue500, DesignSystem.Colors.sky500],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 6, height: 6)
                            Text("Enabled by Default")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $enabledByDefault)
                            .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.blue500))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(minWidth: 720, idealWidth: 920, maxWidth: 1160, minHeight: 620, idealHeight: 760, maxHeight: 900)
        .background(DesignSystem.Colors.backgroundGradientStart)
        .onAppear {
            loadPromptData()
        }
        .onChange(of: prompt?.id) { _ in
            // Reload data if prompt changes (e.g., after loading completes)
            loadPromptData()
        }
    }
    
    private func loadPromptData() {
        if let existingPrompt = prompt {
            field = existingPrompt.field
            promptText = existingPrompt.prompt
            type = existingPrompt.type
            tags = existingPrompt.tags.joined(separator: ", ")
            enabledByDefault = existingPrompt.enabledByDefault
        } else {
            field = ""
            promptText = ""
            type = "client"
            tags = ""
            enabledByDefault = true
        }
    }
    
    private func savePrompt() {
        let tagsArray = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let newPrompt = PromptTemplate(
            id: prompt?.id,
            type: type,
            field: field,
            prompt: promptText,
            tags: tagsArray,
            enabledByDefault: enabledByDefault
        )
        onSave(newPrompt)
    }
}

// Bundle Edit View
struct BundleEditView: View {
    let bundle: PromptBundle?
    let candidatePrompts: [PromptTemplate]
    let onSave: (PromptBundle) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var selectedPromptIds: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bundle == nil ? "Create New Bundle" : "Edit Bundle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(bundle == nil ? "Group prompts together for easy selection" : "Update bundle settings")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .font(.system(size: 15, weight: .medium))
                    Button("Save") {
                        saveBundle()
                    }
                    .disabled(name.isEmpty)
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if name.isEmpty {
                                DesignSystem.Colors.textTertiary
                            } else {
                                DesignSystem.Colors.buttonSkyGradient
                            }
                        }
                    )
                    .cornerRadius(DesignSystem.Radius.sm)
                }
            }
            .padding(24)
            .background(DesignSystem.Colors.cardBackground)
            .overlay(
                Rectangle()
                    .fill(DesignSystem.Colors.cardBorder)
                    .frame(height: 1),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Bundle Name
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.sky500, DesignSystem.Colors.cyan500],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 6, height: 6)
                            Text("Bundle Name *")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        TextField("e.g., Quick Screen, Deep Dive, Culture Fit", text: $name)
                            .textFieldStyle(FormInputFieldStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    // Prompt Selection
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.sky500, DesignSystem.Colors.cyan500],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 6, height: 6)
                            Text("Select Prompts")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        if candidatePrompts.isEmpty {
                            Text("No candidate prompts available. Create prompts first.")
                                .font(.system(size: 13))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .italic()
                                .padding(.vertical, 16)
                        } else {
                            VStack(spacing: 8) {
                                HStack {
                                    Button("Select All") {
                                        selectedPromptIds = Set(candidatePrompts.compactMap { $0.id })
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.sky500)
                                    
                                    Button("Clear All") {
                                        selectedPromptIds = []
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    
                                    Spacer()
                                    
                                    Text("\(selectedPromptIds.count) selected")
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                }
                                .padding(.horizontal, 4)
                                
                                ForEach(candidatePrompts, id: \.id) { prompt in
                                    BundlePromptRow(
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
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(minWidth: 720, idealWidth: 920, maxWidth: 1160, minHeight: 620, idealHeight: 760, maxHeight: 900)
        .background(DesignSystem.Colors.backgroundGradientStart)
        .onAppear {
            if let existingBundle = bundle {
                name = existingBundle.name
                selectedPromptIds = Set(existingBundle.promptIds)
            }
        }
    }
    
    private func saveBundle() {
        let newBundle = PromptBundle(
            id: bundle?.id,
            type: "candidate",
            name: name,
            promptIds: Array(selectedPromptIds)
        )
        onSave(newBundle)
    }
}

struct BundlePromptRow: View {
    let prompt: PromptTemplate
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? DesignSystem.Colors.sky500 : DesignSystem.Colors.textSecondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.field)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                if !prompt.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(prompt.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.sky500.opacity(0.2))
                                .foregroundColor(DesignSystem.Colors.sky500)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(isSelected ? DesignSystem.Colors.sky500.opacity(0.1) : DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                .stroke(isSelected ? DesignSystem.Colors.sky500 : DesignSystem.Colors.cardBorder, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
} 
