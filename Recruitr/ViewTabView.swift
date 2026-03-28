import SwiftUI

struct ViewTabView: View {
    @EnvironmentObject var dataManager: DataManager
    private let shellInset: CGFloat = 14
    private let topShellInset: CGFloat = 6
    var onDeleteRequest: (Record) -> Void
    @Binding var showError: Bool
    @Binding var errorMessage: String
    @Binding var reloadTrigger: Bool
    @State private var selectedRecord: Record? = nil
    @State private var expandedClients = true
    @State private var expandedCandidates = true
    @State private var isEditing = false
    @State private var editedFields: [RecordField] = []
    @State private var editedNotes: String = ""
    @State private var showDeleteConfirm: Bool = false
    @State private var recordPendingDelete: Record? = nil
    @State private var searchText: String = ""
    @State private var recordFilter: RecordListFilter = .all
    @FocusState private var isSearchFocused: Bool
    
    // Computed properties that use dataManager
    private var clients: [Record] {
        dataManager.clientRecords
    }
    
    private var candidates: [Record] {
        dataManager.candidateRecords
    }

    private var filteredClients: [Record] {
        filterRecords(clients)
    }

    private var filteredCandidates: [Record] {
        filterRecords(candidates)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let useSidebarLayout = geometry.size.width >= 760

            ZStack {
                Group {
                    if useSidebarLayout {
                        HSplitView {
                            sidebar
                                .frame(minWidth: 280, idealWidth: 290, maxWidth: 460)

                            detailArea
                        }
                    } else {
                        VStack(spacing: 18) {
                            sidebar
                                .frame(height: min(320, geometry.size.height * 0.34))

                            detailArea
                        }
                    }
                }
                .padding(.horizontal, shellInset)
                .padding(.bottom, shellInset)
                .padding(.top, topShellInset)
                .background(Color("Background").edgesIgnoringSafeArea(.all))

                if dataManager.isLoadingRecords {
                    LoadingOverlay(message: "Loading records...")
                }
            }
        }
        .onAppear {
            // Data is already preloaded, but refresh if needed
            if dataManager.records.isEmpty && !dataManager.isLoadingRecords {
                Task {
                    await dataManager.refreshRecords()
                }
            }
        }
        .onChange(of: reloadTrigger) { _ in
            selectedRecord = nil
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private var sidebar: some View {
        SurfaceCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("View Records")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(isSearchFocused ? DesignSystem.Colors.blue500 : DesignSystem.Colors.textSecondary)

                            TextField("Search name, notes, or AI fields", text: $searchText)
                                .textFieldStyle(.plain)
                                .focused($isSearchFocused)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }

                        Capsule()
                            .fill(isSearchFocused ? DesignSystem.Colors.blue500.opacity(0.8) : DesignSystem.Colors.inputBorder)
                            .frame(height: 2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSearchFocused = true
                    }

                    Picker("", selection: $recordFilter) {
                        ForEach(RecordListFilter.allCases, id: \.self) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(20)

                Divider()
                    .background(DesignSystem.Colors.cardBorder)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Clients", expanded: $expandedClients, accent: .client)
                        if expandedClients {
                            recordSection(records: filteredClients, emptyTitle: "No client matches", emptyDetail: "Try another search or create a client record.")
                        }

                        SectionHeader(title: "Candidates", expanded: $expandedCandidates, accent: .candidate)
                        if expandedCandidates {
                            recordSection(records: filteredCandidates, emptyTitle: "No candidate matches", emptyDetail: "Try another search or create a candidate record.")
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    private var detailArea: some View {
        SurfaceCard(padding: 18) {
            if let record = selectedRecord {
                RecordDetailView(
                    record: record,
                    isEditing: $isEditing,
                    editedFields: $editedFields,
                    editedNotes: $editedNotes,
                    onSave: saveEdits,
                    onDelete: onDeleteRequest
                )
            } else {
                EmptyStateCard(
                    title: "Select a record",
                    detail: "Choose a client or candidate from the list to review extracted fields, notes, and prompts used.",
                    icon: "doc.text.magnifyingglass"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(isPresented: $showDeleteConfirm) {
            return Alert(
                title: Text("Delete Record?"),
                message: Text("Are you sure you want to delete this record?"),
                primaryButton: .destructive(Text("Delete"), action: {
                    if let rec = recordPendingDelete {
                        Task {
                            await MainActor.run {
                                dataManager.beginSavingRecords()
                            }
                            do {
                                try await Recruitr.deleteRecord(rec, databaseId: appwriteDatabaseId, collectionId: appwriteCollectionId)
                                await MainActor.run {
                                    dataManager.removeRecord(rec)
                                    if selectedRecord?.id == rec.id { selectedRecord = nil }
                                }
                            } catch {
                                await MainActor.run {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                            }
                            await MainActor.run {
                                dataManager.finishSavingRecords()
                            }
                        }
                    }
                    recordPendingDelete = nil
                }),
                secondaryButton: .cancel({
                    recordPendingDelete = nil
                })
            )
        }
    }

    @ViewBuilder
    private func recordSection(records: [Record], emptyTitle: String, emptyDetail: String) -> some View {
        if dataManager.isLoadingRecords {
            SectionLoadingView()
        } else {
            let validRecords = records.filter { $0.id != nil }
            if validRecords.isEmpty {
                EmptyStateCard(title: emptyTitle, detail: emptyDetail, icon: "tray")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(validRecords, id: \.id) { record in
                        SidebarItem(record: record, isSelected: selectedRecord?.id == record.id) {
                            selectRecord(record)
                        }
                    }
                }
            }
        }
    }
    
    private func selectRecord(_ record: Record) {
        selectedRecord = record
        editedFields = record.orderedFields
        editedNotes = record.userNotes
        isEditing = false
    }
    
    // Removed loadData() - now using DataManager preloaded data
    
    private func saveEdits() {
        guard var record = selectedRecord else { return }
        record.setOrderedFields(editedFields)
        record.userNotes = editedNotes
        isEditing = false
        Task {
            await MainActor.run {
                dataManager.beginSavingRecords()
            }
            do {
                let updatedRecord = try await updateRecord(record, databaseId: appwriteDatabaseId, collectionId: appwriteCollectionId)
                await MainActor.run {
                    dataManager.updateRecord(updatedRecord)
                    selectedRecord = updatedRecord
                    editedFields = updatedRecord.orderedFields
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run {
                dataManager.finishSavingRecords()
            }
        }
    }
    
    private func deleteRecord(_ record: Record) {
        Task {
            await MainActor.run {
                dataManager.beginSavingRecords()
            }
            do {
                try await Recruitr.deleteRecord(record, databaseId: appwriteDatabaseId, collectionId: appwriteCollectionId)
                await MainActor.run {
                    dataManager.removeRecord(record)
                    if selectedRecord?.id == record.id { selectedRecord = nil }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run {
                dataManager.finishSavingRecords()
            }
        }
    }

    private func filterRecords(_ records: [Record]) -> [Record] {
        records.filter { record in
            let matchesType: Bool
            switch recordFilter {
            case .all:
                matchesType = true
            case .clients:
                matchesType = record.type == RecordType.client.rawValue
            case .candidates:
                matchesType = record.type == RecordType.candidate.rawValue
            }

            guard matchesType else {
                return false
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                return true
            }

            let haystack = [
                record.name,
                RichTextStorage.plainText(from: record.userNotes),
                record.transcript ?? "",
                record.pdfText ?? "",
                record.fieldValues.map { RichTextStorage.plainText(from: $0) }.joined(separator: " ")
            ].joined(separator: "\n")

            return haystack.localizedCaseInsensitiveContains(query)
        }
    }
}

enum RecordListFilter: CaseIterable {
    case all
    case clients
    case candidates

    var title: String {
        switch self {
        case .all:
            return "All"
        case .clients:
            return "Clients"
        case .candidates:
            return "Candidates"
        }
    }
}

struct SectionHeader: View {
    let title: String
    @Binding var expanded: Bool
    let accent: RecordTypeAccent?

    init(title: String, expanded: Binding<Bool>, accent: RecordTypeAccent? = nil) {
        self.title = title
        self._expanded = expanded
        self.accent = accent
    }

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if let accent {
                    Circle()
                        .fill(accent.tint)
                        .frame(width: 8, height: 8)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accent?.tint ?? DesignSystem.Colors.textPrimary)
            }
            Spacer()
            Button(action: { expanded.toggle() }) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }.buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

struct SidebarItem: View {
    let record: Record
    let isSelected: Bool
    let onSelect: () -> Void

    private var accent: RecordTypeAccent {
        record.accent
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(accent.tint)
                    .frame(width: 8, height: 8)
                    .padding(.top, 7)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.name.trimmingCharacters(in: .whitespacesAndNewlines))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    if let docId = record.id {
                        Text("\(accent.label) • \(docId.prefix(8))")
                            .font(.system(size: 11))
                            .foregroundColor(accent.tint.opacity(0.95))
                    }
                    if let preview = record.fieldValues
                        .map({ RichTextStorage.plainText(from: $0) })
                        .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                        Text(preview)
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                isSelected
                ? accent.sectionFill
                : LinearGradient(
                    colors: [DesignSystem.Colors.inputBackground, DesignSystem.Colors.inputBackground],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(isSelected ? accent.subtleBorder : DesignSystem.Colors.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("sidebar-record-\(record.id ?? record.name)")
    }
} 
