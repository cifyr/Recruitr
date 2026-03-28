//
//  ContentView.swift
//  Recruitr
//
//  Created by Caden Warren on 7/23/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    private let collapsedSidebarTabTopInset: CGFloat = 8
    @State private var selectedTab: MainTab = .add
    @State private var isProcessing: Bool = false
    @State private var processingStage: ProcessingStage? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var recordPendingDelete: Record? = nil
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var reloadViewTab = false
    @State private var isDone: Bool = false
    @State private var isAppSidebarHidden = false
    
    enum Tab {
        case view, add
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if isAppSidebarHidden {
                mainContent
            } else {
                HSplitView {
                    SidebarNavigation(
                        selectedTab: $selectedTab,
                        isCompact: false,
                        onCollapseSidebar: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAppSidebarHidden = true
                            }
                        }
                    )
                    .frame(minWidth: 210, idealWidth: 240, maxWidth: 320)
                    .allowsHitTesting(!isProcessing && !isDone)

                    mainContent
                }
            }
        }
        .overlay(
            Group {
                if isProcessing {
                    if let processingStage {
                        ProcessingOverlay(stage: processingStage)
                    }
                } else if isDone {
                    DoneOverlay(onContinue: { isDone = false })
                }
            }
        )
        .confirmationDialog("Delete Record?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        if let rec = recordPendingDelete {
                            Task {
                                await MainActor.run {
                                    dataManager.beginSavingRecords()
                                }
                                do {
                                    try await Recruitr.deleteRecord(rec, databaseId: appwriteDatabaseId, collectionId: appwriteCollectionId)
                                    await MainActor.run {
                                        dataManager.removeRecord(rec)
                                        reloadViewTab.toggle()
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
                    }
            Button("Cancel", role: .cancel) {
                recordPendingDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this record?")
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    DesignSystem.Colors.backgroundGradientStart,
                    DesignSystem.Colors.backgroundGradientMiddle,
                    DesignSystem.Colors.backgroundGradientEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            Group {
                if selectedTab == .view {
                    ViewTabView(
                        onDeleteRequest: { rec in
                            recordPendingDelete = rec
                            showDeleteConfirm = true
                        },
                        showError: $showError,
                        errorMessage: $errorMessage,
                        reloadTrigger: $reloadViewTab
                    )
                    .environmentObject(dataManager)
                } else if selectedTab == .add {
                    AddTabView(isProcessing: $isProcessing, processingStage: $processingStage, isDone: $isDone)
                        .environmentObject(dataManager)
                } else if selectedTab == .prompts {
                    PromptManagementView()
                        .environmentObject(dataManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isAppSidebarHidden {
                sidebarEdgeTab
                    .padding(.top, collapsedSidebarTabTopInset)
                    .zIndex(5)
            }
        }
    }

    private var sidebarEdgeTab: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isAppSidebarHidden = false
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .frame(width: 28, height: 78)
            .background(DesignSystem.Colors.panelBackground)
            .overlay(
                SidebarEdgeTabShape()
                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
            )
            .clipShape(SidebarEdgeTabShape())
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .help("Show Menu")
    }
}

private struct SidebarEdgeTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(12, rect.height * 0.2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

#Preview {
    ContentView()
}

struct DoneOverlay: View {
    let onContinue: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .background(.ultraThinMaterial)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Success icon with animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.2),
                                    Color(red: 16/255.0, green: 185/255.0, blue: 129/255.0).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.5), lineWidth: 2)
                                .frame(width: 80, height: 80)
                        )
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 74/255.0, green: 222/255.0, blue: 128/255.0))
                }
                .scaleEffect(1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: true)
                
                VStack(spacing: 8) {
                    Text("Success!")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("Your record has been created")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            DesignSystem.Colors.buttonBlueGradient
                        )
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(40)
            .frame(maxWidth: 400)
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
            .cornerRadius(DesignSystem.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: true)
    }
}
