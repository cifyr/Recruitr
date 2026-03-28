import SwiftUI

struct MarkdownTextView: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
                    .padding(8)
            }
            ScrollView {
                MarkdownRenderer(text: text)
                    .padding(8)
            }
            TextEditor(text: $text)
                .opacity(text.isEmpty ? 0.25 : 1)
                .background(Color.clear)
                .padding(4)
        }
        .background(DesignSystem.Colors.inputBackground)
        .cornerRadius(DesignSystem.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .stroke(DesignSystem.Colors.inputBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
    }
}

struct MarkdownRenderer: View {
    let text: String
    var foregroundColor: Color?

    var body: some View {
        parsedText
    }

    var parsedText: Text {
        let pattern = #"\*\*(.+?)\*\*"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsText = text as NSString
        var lastIndex = 0
        var result = Text("")

        if let regex = regex {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let rangeBefore = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                if rangeBefore.length > 0 {
                    let before = nsText.substring(with: rangeBefore)
                    var textBefore = Text(before)
                    if let color = foregroundColor {
                        textBefore = textBefore.foregroundColor(color)
                    }
                    result = result + textBefore
                }
                let boldRange = match.range(at: 1)
                let boldText = nsText.substring(with: boldRange)
                var textBold = Text(boldText).bold()
                if let color = foregroundColor {
                    textBold = textBold.foregroundColor(color)
                }
                result = result + textBold
                lastIndex = match.range.location + match.range.length
            }
            // Add any trailing text
            if lastIndex < nsText.length {
                let trailing = nsText.substring(from: lastIndex)
                var textTrailing = Text(trailing)
                if let color = foregroundColor {
                    textTrailing = textTrailing.foregroundColor(color)
                }
                result = result + textTrailing
            }
            return result
        } else {
            var textResult = Text(text)
            if let color = foregroundColor {
                textResult = textResult.foregroundColor(color)
            }
            return textResult
        }
    }
} 
