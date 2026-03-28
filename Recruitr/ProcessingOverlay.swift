import SwiftUI

struct ProcessingOverlay: View {
    let stage: ProcessingStage

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .background(.ultraThinMaterial)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Animated spinner
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(DesignSystem.Colors.backgroundGradientMiddle, lineWidth: 4)
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(DesignSystem.Colors.blue500, lineWidth: 4)
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: stage)
                    
                    // Inner ring (reverse)
                    Circle()
                        .trim(from: 0, to: 0.5)
                        .stroke(DesignSystem.Colors.sky500, lineWidth: 4)
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(90))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: stage)
                }
                
                VStack(spacing: 4) {
                    Text(stage.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(stage.detail)
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    if let progressText = stage.progressText {
                        Text(progressText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.sky500)
                    }
                }

                if let progress = stage.progress {
                    VStack(spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(DesignSystem.Colors.sky500)

                        Text("\(Int(progress * 100))% complete")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(40)
            .frame(maxWidth: 440)
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
        .animation(.easeInOut, value: stage)
    }
}
