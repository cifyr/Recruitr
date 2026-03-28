import SwiftUI

enum MainTab {
    case view, add, prompts
}

struct CustomTabBar: View {
    @Binding var selectedTab: MainTab
    var body: some View {
        HStack {
            TabBarButton(icon: "eye", label: "View", isSelected: selectedTab == .view) {
                selectedTab = .view
            }
            Spacer()
            TabBarButton(icon: "plus", label: "Add", isSelected: selectedTab == .add) {
                selectedTab = .add
            }
            Spacer()
            TabBarButton(icon: "text.bubble", label: "Prompts", isSelected: selectedTab == .prompts) {
                selectedTab = .prompts
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
        .background(Color(red: 22/255, green: 27/255, blue: 38/255))
        .cornerRadius(24)
        .shadow(radius: 8)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? Color.purple : Color.gray.opacity(0.7))
                Text(label)
                    .font(.caption)
                    .foregroundColor(isSelected ? Color.purple : Color.gray.opacity(0.7))
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 