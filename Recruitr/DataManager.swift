//
//  DataManager.swift
//  Recruitr
//
//  Created for preloading data at app startup
//

import Foundation
import SwiftUI

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var records: [Record] = []
    @Published var prompts: [PromptTemplate] = []
    @Published var promptBundles: [PromptBundle] = []
    @Published private(set) var isLoadingRecords: Bool = false
    @Published private(set) var isLoadingPrompts: Bool = false
    @Published private(set) var isLoadingBundles: Bool = false
    @Published private(set) var isSavingRecords: Bool = false
    @Published private(set) var isSavingPrompts: Bool = false
    @Published private(set) var isSavingBundles: Bool = false
    @Published var lastError: String? = nil
    
    // Computed properties for filtered data
    var clientRecords: [Record] {
        records.filter { $0.type == "client" }
    }
    
    var candidateRecords: [Record] {
        records.filter { $0.type == "candidate" }
    }
    
    var clientPrompts: [PromptTemplate] {
        prompts.filter { $0.type == "client" }
    }
    
    var candidatePrompts: [PromptTemplate] {
        prompts.filter { $0.type == "candidate" }
    }

    var clientPromptBundles: [PromptBundle] {
        promptBundles.filter { $0.type == RecordType.client.rawValue }
    }

    var candidatePromptBundles: [PromptBundle] {
        promptBundles.filter { $0.type == RecordType.candidate.rawValue }
    }

    var isLoadingAny: Bool {
        isLoadingRecords || isLoadingPrompts || isLoadingBundles
    }
    
    private init() {
        // Private initializer for singleton
    }
    
    /// Load all data from the database (records and prompts)
    func loadAllData() async {
        lastError = nil
        isLoadingRecords = true
        isLoadingPrompts = true
        isLoadingBundles = true
        
        // Load records, prompts, and bundles in parallel
        async let recordsTask = loadRecords()
        async let promptsTask = loadPrompts()
        async let bundlesTask = loadBundles()
        
        let (recordsResult, promptsResult, bundlesResult) = await (recordsTask, promptsTask, bundlesTask)
        
        // Update state
        switch recordsResult {
        case .success(let loadedRecords):
            self.records = loadedRecords
        case .failure(let error):
            self.lastError = "Failed to load records: \(error.localizedDescription)"
            AppLogger.data.error("Failed to load records: \(error.localizedDescription)")
        }
        
        switch promptsResult {
        case .success(let loadedPrompts):
            self.prompts = loadedPrompts
        case .failure(let error):
            // If prompts fail, append to error (don't overwrite records error)
            if let existingError = self.lastError {
                self.lastError = "\(existingError)\nFailed to load prompts: \(error.localizedDescription)"
            } else {
                self.lastError = "Failed to load prompts: \(error.localizedDescription)"
            }
            AppLogger.data.error("Failed to load prompts: \(error.localizedDescription)")
        }

        switch bundlesResult {
        case .success(let loadedBundles):
            self.promptBundles = loadedBundles
        case .failure(let error):
            if let existingError = self.lastError {
                self.lastError = "\(existingError)\nFailed to load bundles: \(error.localizedDescription)"
            } else {
                self.lastError = "Failed to load bundles: \(error.localizedDescription)"
            }
            AppLogger.data.error("Failed to load bundles: \(error.localizedDescription)")
        }
        
        isLoadingRecords = false
        isLoadingPrompts = false
        isLoadingBundles = false
    }
    
    /// Load records from the database
    private func loadRecords() async -> Result<[Record], Error> {
        do {
            let loadedRecords = try await fetchRecords(
                databaseId: appwriteDatabaseId,
                collectionId: appwriteCollectionId
            )
            return .success(loadedRecords)
        } catch {
            return .failure(error)
        }
    }
    
    /// Load prompts from the database
    private func loadPrompts() async -> Result<[PromptTemplate], Error> {
        do {
            let loadedPrompts = try await fetchPromptTemplates()
            return .success(loadedPrompts)
        } catch {
            return .failure(error)
        }
    }

    /// Load prompt bundles from the database
    private func loadBundles() async -> Result<[PromptBundle], Error> {
        do {
            let loadedBundles = try await fetchPromptBundles()
            return .success(loadedBundles)
        } catch {
            return .failure(error)
        }
    }
    
    /// Refresh records from the database
    func refreshRecords() async {
        lastError = nil
        isLoadingRecords = true
        
        let result = await loadRecords()
        switch result {
        case .success(let loadedRecords):
            self.records = loadedRecords
        case .failure(let error):
            self.lastError = "Failed to refresh records: \(error.localizedDescription)"
            AppLogger.data.error("Failed to refresh records: \(error.localizedDescription)")
        }
        
        isLoadingRecords = false
    }
    
    /// Refresh prompts from the database
    func refreshPrompts() async {
        lastError = nil
        isLoadingPrompts = true
        
        let result = await loadPrompts()
        switch result {
        case .success(let loadedPrompts):
            self.prompts = loadedPrompts
        case .failure(let error):
            self.lastError = "Failed to refresh prompts: \(error.localizedDescription)"
            AppLogger.data.error("Failed to refresh prompts: \(error.localizedDescription)")
        }
        
        isLoadingPrompts = false
    }

    /// Refresh prompt bundles from the database
    func refreshPromptBundles() async {
        lastError = nil
        isLoadingBundles = true

        let result = await loadBundles()
        switch result {
        case .success(let loadedBundles):
            self.promptBundles = loadedBundles
        case .failure(let error):
            self.lastError = "Failed to refresh bundles: \(error.localizedDescription)"
            AppLogger.data.error("Failed to refresh bundles: \(error.localizedDescription)")
        }

        isLoadingBundles = false
    }
    
    /// Add a new record to the local cache (after creating it)
    func addRecord(_ record: Record) {
        records.insert(record, at: 0) // Insert at beginning (newest first)
    }

    func beginSavingRecords() {
        isSavingRecords = true
    }

    func finishSavingRecords() {
        isSavingRecords = false
    }
    
    /// Update a record in the local cache
    func updateRecord(_ record: Record) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        }
    }
    
    /// Remove a record from the local cache
    func removeRecord(_ record: Record) {
        records.removeAll { $0.id == record.id }
    }
    
    /// Add a new prompt to the local cache
    func addPrompt(_ prompt: PromptTemplate) {
        prompts.append(prompt)
    }

    func beginSavingPrompts() {
        isSavingPrompts = true
    }

    func finishSavingPrompts() {
        isSavingPrompts = false
    }
    
    /// Update a prompt in the local cache
    func updatePrompt(_ prompt: PromptTemplate) {
        if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
            prompts[index] = prompt
        }
    }
    
    /// Remove a prompt from the local cache
    func removePrompt(_ prompt: PromptTemplate) {
        prompts.removeAll { $0.id == prompt.id }
    }

    func beginSavingBundles() {
        isSavingBundles = true
    }

    func finishSavingBundles() {
        isSavingBundles = false
    }

    func addPromptBundle(_ bundle: PromptBundle) {
        promptBundles.append(bundle)
    }

    func updatePromptBundle(_ bundle: PromptBundle) {
        if let index = promptBundles.firstIndex(where: { $0.id == bundle.id }) {
            promptBundles[index] = bundle
        }
    }

    func removePromptBundle(_ bundle: PromptBundle) {
        promptBundles.removeAll { $0.id == bundle.id }
    }
    
    /// Get field prompts for a specific type (converts PromptTemplate to FieldPrompt)
    func getFieldPrompts(for type: String) -> [FieldPrompt] {
        let filteredPrompts = prompts.filter { $0.type == type }
        return filteredPrompts.map { FieldPrompt(field: $0.field, prompt: $0.prompt) }
    }

    func loadUITestData() {
        records = [
            Record(
                id: "candidate-1",
                name: "Taylor Candidate",
                type: RecordType.candidate.rawValue,
                fields: [
                    RecordField(key: "summary", value: "Experienced recruiter"),
                    RecordField(key: "location", value: "Chicago")
                ],
                userNotes: "Follow up this week",
                promptIdsUsed: ["candidate-summary", "candidate-location"]
            ),
            Record(
                id: "client-1",
                name: "Acme Client",
                type: RecordType.client.rawValue,
                fields: [
                    RecordField(key: "summary", value: "High-priority account")
                ],
                userNotes: "Needs 3 hires this quarter"
            )
        ]

        prompts = [
            PromptTemplate(id: "candidate-summary", type: RecordType.candidate.rawValue, field: "summary", prompt: "Summarize the candidate"),
            PromptTemplate(id: "candidate-location", type: RecordType.candidate.rawValue, field: "location", prompt: "Find the location"),
            PromptTemplate(id: "client-summary", type: RecordType.client.rawValue, field: "summary", prompt: "Summarize the client")
        ]

        promptBundles = [
            PromptBundle(id: "candidate-bundle-1", type: RecordType.candidate.rawValue, name: "Quick Screen", promptIds: ["candidate-summary", "candidate-location"])
        ]

        lastError = nil
        isLoadingRecords = false
        isLoadingPrompts = false
        isLoadingBundles = false
        isSavingRecords = false
        isSavingPrompts = false
        isSavingBundles = false
    }
}
