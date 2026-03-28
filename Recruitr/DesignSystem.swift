import SwiftUI
import AppKit

struct DesignSystem {
    // Colors - Based on React design
    struct Colors {
        // Background colors
        static let backgroundGradientStart = Color(red: 2/255.0, green: 6/255.0, blue: 23/255.0) // slate-950
        static let backgroundGradientMiddle = Color(red: 15/255.0, green: 23/255.0, blue: 42/255.0) // slate-900
        static let backgroundGradientEnd = Color(red: 2/255.0, green: 6/255.0, blue: 23/255.0) // slate-950
        
        // Sidebar colors
        static let sidebarBackground = Color(red: 2/255.0, green: 6/255.0, blue: 23/255.0).opacity(0.5) // slate-950/50
        static let sidebarBorder = Color.white.opacity(0.05)
        
        // Card/Container colors
        static let cardBackground = Color.white.opacity(0.05)
        static let panelBackground = Color(red: 9/255.0, green: 15/255.0, blue: 32/255.0).opacity(0.88)
        static let cardBorder = Color.white.opacity(0.1)
        static let cardBorderHover = Color.white.opacity(0.15)
        static let inputBackground = Color.white.opacity(0.06)
        static let inputBorder = Color.white.opacity(0.14)
        
        // Text colors
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 148/255.0, green: 163/255.0, blue: 184/255.0) // slate-400
        static let textTertiary = Color(red: 71/255.0, green: 85/255.0, blue: 105/255.0) // slate-600
        
        // Accent colors (Blue to Cyan gradients)
        static let blue500 = Color(red: 59/255.0, green: 130/255.0, blue: 246/255.0)
        static let blue600 = Color(red: 37/255.0, green: 99/255.0, blue: 235/255.0)
        static let emerald500 = Color(red: 16/255.0, green: 185/255.0, blue: 129/255.0)
        static let emerald600 = Color(red: 5/255.0, green: 150/255.0, blue: 105/255.0)
        static let cyan500 = Color(red: 6/255.0, green: 182/255.0, blue: 212/255.0)
        static let sky500 = Color(red: 14/255.0, green: 165/255.0, blue: 233/255.0)
        static let sky600 = Color(red: 2/255.0, green: 132/255.0, blue: 199/255.0)
        static let success = Color(red: 34/255.0, green: 197/255.0, blue: 94/255.0)
        static let warning = Color(red: 245/255.0, green: 158/255.0, blue: 11/255.0)
        
        // Selected/Active states
        static let selectedBackground = LinearGradient(
            colors: [blue500.opacity(0.1), cyan500.opacity(0.1)],
            startPoint: .leading,
            endPoint: .trailing
        )
        static let selectedBorder = blue500.opacity(0.2)
        
        // Button gradients
        static let buttonBlueGradient = LinearGradient(
            colors: [blue500, blue600],
            startPoint: .leading,
            endPoint: .trailing
        )
        static let buttonGreenGradient = LinearGradient(
            colors: [emerald500, emerald600],
            startPoint: .leading,
            endPoint: .trailing
        )
        static let buttonSkyGradient = LinearGradient(
            colors: [sky500, sky600],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // Corner Radius
    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
    
    // Sidebar width
    static let sidebarWidth: CGFloat = 256
}

enum RecordTypeAccent {
    case client
    case candidate

    init(type: String) {
        switch type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case RecordType.client.rawValue:
            self = .client
        default:
            self = .candidate
        }
    }

    var label: String {
        switch self {
        case .client:
            return "Client"
        case .candidate:
            return "Candidate"
        }
    }

    var tint: Color {
        switch self {
        case .client:
            return DesignSystem.Colors.emerald500
        case .candidate:
            return DesignSystem.Colors.blue500
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .client:
            return DesignSystem.Colors.buttonGreenGradient
        case .candidate:
            return DesignSystem.Colors.buttonBlueGradient
        }
    }

    var subtleFill: Color {
        tint.opacity(0.12)
    }

    var subtleBorder: Color {
        tint.opacity(0.28)
    }

    var sectionFill: LinearGradient {
        switch self {
        case .client:
            return LinearGradient(
                colors: [
                    DesignSystem.Colors.emerald500.opacity(0.14),
                    DesignSystem.Colors.success.opacity(0.08)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .candidate:
            return LinearGradient(
                colors: [
                    DesignSystem.Colors.blue500.opacity(0.14),
                    DesignSystem.Colors.sky500.opacity(0.08)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

extension Record {
    var accent: RecordTypeAccent {
        RecordTypeAccent(type: type)
    }
}

extension PromptTemplate {
    var accent: RecordTypeAccent {
        RecordTypeAccent(type: type)
    }
}

// Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.buttonBlueGradient)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

enum ResponsiveWidthCategory {
    case compact
    case regular
    case wide

    init(width: CGFloat) {
        switch width {
        case ..<980:
            self = .compact
        case ..<1380:
            self = .regular
        default:
            self = .wide
        }
    }

    var usesStackedPanels: Bool {
        self == .compact
    }
}

struct RichTextFormattingState: Equatable {
    var isBold = false
    var isItalic = false
    var isUnderlined = false
}

enum RichTextStorage {
    static let baseFontSize: CGFloat = 15
    static var baseFont: NSFont {
        NSFont.systemFont(ofSize: baseFontSize, weight: .regular)
    }

    static func attributedString(from storedText: String) -> NSAttributedString {
        if looksLikeHTML(storedText), let htmlAttributed = decodeHTML(storedText) {
            return normalizedAttributedString(htmlAttributed)
        }

        return normalizedAttributedString(decodeLegacyMarkdown(storedText))
    }

    static func plainText(from storedText: String) -> String {
        attributedString(from: storedText).string
    }

    static func storedString(from attributedString: NSAttributedString) -> String {
        let normalized = normalizedAttributedString(attributedString)
        guard containsRichFormatting(normalized) else {
            return normalized.string
        }

        let export = NSMutableAttributedString(attributedString: normalized)
        let fullRange = NSRange(location: 0, length: export.length)
        export.removeAttribute(.foregroundColor, range: fullRange)
        export.removeAttribute(.backgroundColor, range: fullRange)

        do {
            let data = try export.data(
                from: fullRange,
                documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ]
            )
            return String(data: data, encoding: .utf8) ?? export.string
        } catch {
            return export.string
        }
    }

    static func formattingState(for attributedString: NSAttributedString, selectedRange: NSRange) -> RichTextFormattingState {
        guard attributedString.length > 0 else {
            return RichTextFormattingState()
        }

        let lookupLocation: Int
        if selectedRange.location < attributedString.length {
            lookupLocation = selectedRange.location
        } else {
            lookupLocation = max(0, attributedString.length - 1)
        }

        let attributes = attributedString.attributes(at: lookupLocation, effectiveRange: nil)
        let font = (attributes[.font] as? NSFont) ?? baseFont
        let traits = NSFontManager.shared.traits(of: font)
        let underlineValue = (attributes[.underlineStyle] as? Int) ?? 0

        return RichTextFormattingState(
            isBold: traits.contains(.boldFontMask),
            isItalic: traits.contains(.italicFontMask),
            isUnderlined: underlineValue != 0
        )
    }

    private static func looksLikeHTML(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("<!doctype html")
            || trimmed.hasPrefix("<html")
            || trimmed.hasPrefix("<body")
            || trimmed.hasPrefix("<span")
            || trimmed.hasPrefix("<p")
            || trimmed.hasPrefix("<div")
            || trimmed.contains("<strong")
            || trimmed.contains("<em")
            || trimmed.contains("<u")
            || trimmed.contains("<br")
    }

    private static func decodeHTML(_ text: String) -> NSAttributedString? {
        guard let data = text.data(using: .utf8) else {
            return nil
        }

        return try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }

    private static func decodeLegacyMarkdown(_ text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString()
        let nsText = text as NSString
        let pattern = #"\*\*(.+?)\*\*|\*(.+?)\*"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        var lastIndex = 0

        guard let regex else {
            attributed.append(NSAttributedString(string: text))
            return attributed
        }

        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            let beforeRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
            if beforeRange.length > 0 {
                attributed.append(NSAttributedString(string: nsText.substring(with: beforeRange)))
            }

            if match.range(at: 1).location != NSNotFound {
                let boldText = nsText.substring(with: match.range(at: 1))
                attributed.append(
                    NSAttributedString(
                        string: boldText,
                        attributes: [.font: makeFont(size: baseFontSize, bold: true, italic: false)]
                    )
                )
            } else if match.range(at: 2).location != NSNotFound {
                let italicText = nsText.substring(with: match.range(at: 2))
                attributed.append(
                    NSAttributedString(
                        string: italicText,
                        attributes: [.font: makeFont(size: baseFontSize, bold: false, italic: true)]
                    )
                )
            }

            lastIndex = match.range.location + match.range.length
        }

        if lastIndex < nsText.length {
            attributed.append(NSAttributedString(string: nsText.substring(from: lastIndex)))
        }

        return attributed
    }

    private static func containsRichFormatting(_ attributedString: NSAttributedString) -> Bool {
        guard attributedString.length > 0 else {
            return false
        }

        let fullRange = NSRange(location: 0, length: attributedString.length)
        var hasFormatting = false

        attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, _, stop in
            let underlineValue = (attributes[.underlineStyle] as? Int) ?? 0
            let font = (attributes[.font] as? NSFont) ?? baseFont
            let traits = NSFontManager.shared.traits(of: font)

            if underlineValue != 0 || traits.contains(.boldFontMask) || traits.contains(.italicFontMask) {
                hasFormatting = true
                stop.pointee = true
            }
        }

        return hasFormatting
    }

    private static func normalizedAttributedString(_ attributedString: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        guard mutable.length > 0 else {
            return mutable
        }

        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.beginEditing()
        mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            let font = value as? NSFont
            let traits = font.map { NSFontManager.shared.traits(of: $0) } ?? []
            let size = max(font?.pointSize ?? baseFontSize, baseFontSize)
            let normalizedFont = makeFont(
                size: size,
                bold: traits.contains(.boldFontMask),
                italic: traits.contains(.italicFontMask)
            )
            mutable.addAttribute(.font, value: normalizedFont, range: range)
        }
        mutable.addAttribute(.foregroundColor, value: NSColor.white, range: fullRange)
        mutable.endEditing()
        return mutable
    }

    static func editorFont(size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        let weight: NSFont.Weight = bold ? .semibold : .regular
        var font = NSFont.systemFont(ofSize: size, weight: weight)
        if italic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
    }

    private static func makeFont(size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        editorFont(size: size, bold: bold, italic: italic)
    }
}

struct ProcessingStage: Equatable {
    let title: String
    let detail: String
    let progress: Double?
    let currentStep: Int?
    let totalSteps: Int?

    init(
        title: String,
        detail: String,
        progress: Double? = nil,
        currentStep: Int? = nil,
        totalSteps: Int? = nil
    ) {
        self.title = title
        self.detail = detail
        self.progress = progress
        self.currentStep = currentStep
        self.totalSteps = totalSteps
    }

    var progressText: String? {
        guard let currentStep, let totalSteps, totalSteps > 0 else {
            return nil
        }

        return "Step \(currentStep) of \(totalSteps)"
    }
}

struct SurfaceCard<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(DesignSystem.Colors.panelBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
    }
}

struct FormSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

struct StatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }
}

struct EmptyStateCard: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        SurfaceCard {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }
}

struct UsageMetricTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(DesignSystem.Colors.inputBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
    }
}

struct FormInputFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 14))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.inputBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(DesignSystem.Colors.inputBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .foregroundColor(DesignSystem.Colors.textPrimary)
    }
}

struct SearchFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DesignSystem.Colors.inputBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .foregroundColor(DesignSystem.Colors.textPrimary)
    }
}
