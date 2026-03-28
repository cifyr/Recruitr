import SwiftUI

// Reusable loading spinner component
struct LoadingSpinner: View {
    var size: CGFloat = 32
    var lineWidth: CGFloat = 3
    
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    LinearGradient(
                        colors: [DesignSystem.Colors.blue500, DesignSystem.Colors.sky500],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
        }
        .onAppear {
            rotation = 360
        }
    }
}

// Full screen loading overlay
struct LoadingOverlay: View {
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .background(.ultraThinMaterial)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                LoadingSpinner(size: 48, lineWidth: 4)
                
                if let message = message {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(32)
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
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }
}

// Inline loading view for sections
struct SectionLoadingView: View {
    var body: some View {
        HStack(spacing: 12) {
            LoadingSpinner(size: 20, lineWidth: 2)
            Text("Loading...")
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

