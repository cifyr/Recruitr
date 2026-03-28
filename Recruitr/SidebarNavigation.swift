import SwiftUI

struct SidebarNavigation: View {
    @Binding var selectedTab: MainTab
    let isCompact: Bool
    let onCollapseSidebar: (() -> Void)?

    private var showsLabels: Bool { !isCompact }
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo/Brand Section
            VStack(alignment: showsLabels ? .leading : .center, spacing: 0) {
                HStack(spacing: showsLabels ? 12 : 0) {
                    // Logo Icon
                    ZStack {
                        LinearGradient(
                            colors: [DesignSystem.Colors.blue500, DesignSystem.Colors.cyan500],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(width: 40, height: 40)
                    .cornerRadius(12)
                    .shadow(color: DesignSystem.Colors.blue500.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    if showsLabels {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recruitr")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text("AI-Powered CRM")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        Spacer(minLength: 0)

                        if let onCollapseSidebar {
                            Button(action: onCollapseSidebar) {
                                Image(systemName: "sidebar.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .frame(width: 28, height: 28)
                                    .background(DesignSystem.Colors.inputBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .help("Hide Menu")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: showsLabels ? .leading : .center)
                .padding(.horizontal, showsLabels ? 24 : 0)
                .padding(.top, 22)
                .padding(.bottom, 16)

                Rectangle()
                    .fill(DesignSystem.Colors.sidebarBorder)
                    .frame(height: 1)
                    .padding(.horizontal, showsLabels ? 20 : 14)
            }
            
            // Navigation Buttons
            VStack(spacing: 10) {
                NavButton(
                    icon: "eye",
                    label: "View Records",
                    isSelected: selectedTab == .view,
                    isCompact: isCompact
                ) {
                    selectedTab = .view
                }
                
                NavButton(
                    icon: "plus",
                    label: "Add New",
                    isSelected: selectedTab == .add,
                    isCompact: isCompact
                ) {
                    selectedTab = .add
                }
                
                NavButton(
                    icon: "text.bubble",
                    label: "AI Prompts",
                    isSelected: selectedTab == .prompts,
                    isCompact: isCompact
                ) {
                    selectedTab = .prompts
                }
            }
            .padding(.horizontal, showsLabels ? 14 : 10)
            .padding(.top, 18)
            
            Spacer()
            
            // Footer
            if showsLabels {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(DesignSystem.Colors.sidebarBorder)
                        .frame(height: 1)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recruitr GitHub Demo")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("Local mock data only")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.blue500.opacity(0.05),
                                        DesignSystem.Colors.cyan500.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DesignSystem.Colors.blue500.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 22)
                }
            }
        }
        .background(DesignSystem.Colors.sidebarBackground)
        .overlay(
            Rectangle()
                .fill(DesignSystem.Colors.sidebarBorder)
                .frame(width: 1),
            alignment: .trailing
        )
    }
}

struct NavButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let isCompact: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .frame(width: 20)
                
                if !isCompact {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                }
                
                if !isCompact {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
            .padding(.horizontal, isCompact ? 0 : 16)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.blue500.opacity(0.1),
                                        DesignSystem.Colors.cyan500.opacity(0.1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DesignSystem.Colors.blue500.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: DesignSystem.Colors.blue500.opacity(0.05), radius: 8, x: 0, y: 4)
                    } else {
                        Color.clear
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .help(label)
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
