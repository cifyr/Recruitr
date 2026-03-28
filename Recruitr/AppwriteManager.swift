import Foundation

let appwriteEndpoint = DemoEnvironment.appwriteEndpointPlaceholder
let appwriteProjectId = DemoEnvironment.appwriteProjectPlaceholder
let appwriteDatabaseId = DemoEnvironment.appwriteDatabasePlaceholder
let appwriteCollectionId = DemoEnvironment.recordsCollectionPlaceholder
let promptsDatabaseId = DemoEnvironment.appwriteDatabasePlaceholder
let promptsCollectionId = DemoEnvironment.promptsCollectionPlaceholder
let bundlesCollectionId = DemoEnvironment.bundlesCollectionPlaceholder

func appwriteCreateRecord(_ record: Record, databaseId: String, collectionId: String) async throws -> Record {
    _ = (databaseId, collectionId)
    return await DemoStore.shared.createRecord(record)
}

func fetchRecords(databaseId: String, collectionId: String) async throws -> [Record] {
    _ = (databaseId, collectionId)
    return await DemoStore.shared.fetchRecords()
}

func updateRecord(_ record: Record, databaseId: String, collectionId: String) async throws -> Record {
    _ = (databaseId, collectionId)
    return try await DemoStore.shared.updateRecord(record)
}

func deleteRecord(_ record: Record, databaseId: String, collectionId: String) async throws {
    _ = (databaseId, collectionId)
    await DemoStore.shared.deleteRecord(record)
}

func createPromptTemplate(_ prompt: PromptTemplate) async throws -> PromptTemplate {
    await DemoStore.shared.createPromptTemplate(prompt, preserveProvidedID: false)
}

func createPromptTemplateWithId(_ prompt: PromptTemplate) async throws -> PromptTemplate {
    await DemoStore.shared.createPromptTemplate(prompt, preserveProvidedID: true)
}

func fetchPromptTemplates(type: String? = nil) async throws -> [PromptTemplate] {
    await DemoStore.shared.fetchPromptTemplates(type: type)
}

func updatePromptTemplate(_ prompt: PromptTemplate) async throws -> PromptTemplate {
    try await DemoStore.shared.updatePromptTemplate(prompt)
}

func deletePromptTemplate(_ prompt: PromptTemplate) async throws {
    await DemoStore.shared.deletePromptTemplate(prompt)
}

func createPromptBundle(_ bundle: PromptBundle) async throws -> PromptBundle {
    await DemoStore.shared.createPromptBundle(bundle)
}

func fetchPromptBundles(type: String? = nil) async throws -> [PromptBundle] {
    await DemoStore.shared.fetchPromptBundles(type: type)
}

func updatePromptBundle(_ bundle: PromptBundle) async throws -> PromptBundle {
    try await DemoStore.shared.updatePromptBundle(bundle)
}

func deletePromptBundle(_ bundle: PromptBundle) async throws {
    await DemoStore.shared.deletePromptBundle(bundle)
}
