import SwiftUI
import AppKit

@main
struct RecruitrApp: App {
    @StateObject private var dataManager = DataManager.shared
    private let isUITestMode = ProcessInfo.processInfo.arguments.contains("UITEST_MODE")

    init() {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .preferredColorScheme(.dark)
                .environment(\.colorScheme, .dark)
                .task {
                    if isUITestMode {
                        dataManager.loadUITestData()
                    } else {
                        await dataManager.loadAllData()
                    }
                }
        }
    }
}
