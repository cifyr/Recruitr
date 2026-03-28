import SwiftUI
import AppKit

enum RecordEditorFocus: Hashable {
    case field(String)
    case notes
}

struct RecordDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    let record: Record
    @Binding var isEditing: Bool
    @Binding var editedFields: [RecordField]
    @Binding var editedNotes: String
    let onSave: () -> Void
    let onDelete: (Record) -> Void
    @State private var showConfirmDelete = false
    @State private var activeEditor: RecordEditorFocus? = nil
    @State private var fieldHeights: [String: CGFloat] = [:]
    @State private var notesHeight: CGFloat = 80
    @State private var activeTextView: NSTextView?
    @State private var formattingState = RichTextFormattingState()
    @State private var preserveEditorFocus = false
    
    // Computed property that uses dataManager
    private var fetchedPrompts: [FieldPrompt] {
        dataManager.getFieldPrompts(for: record.type)
    }
    
    private var isLoadingPrompts: Bool {
        dataManager.isLoadingPrompts
    }

    private var displayedFields: [RecordField] {
        editedFields.isEmpty ? record.orderedFields : editedFields
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if isLoadingPrompts && fetchedPrompts.isEmpty {
                Spacer()
                SectionLoadingView()
                    .padding(.vertical, 40)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !displayedFields.isEmpty {
                            detailSectionCard(title: "AI Fields") {
                                fieldsSection
                            }
                        }

                        userNotesSection

                        if let transcript = record.transcript, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            detailSectionCard(title: "Transcript") {
                                MarkdownRenderer(text: transcript, foregroundColor: DesignSystem.Colors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if let pdfText = record.pdfText, !pdfText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            detailSectionCard(title: "Document Text") {
                                MarkdownRenderer(text: pdfText, foregroundColor: DesignSystem.Colors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        bottomSection
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            endInlineEditing()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            // Prompts are already preloaded, but refresh if needed
            if dataManager.prompts.isEmpty && !dataManager.isLoadingPrompts {
                Task {
                    await dataManager.refreshPrompts()
                }
            }
        }
        .onChange(of: record.id) { _ in
            endInlineEditing()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(record.name)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: 8) {
                    StatusPill(
                        text: record.accent.label,
                        tint: record.accent.tint
                    )

                    if isEditing {
                        StatusPill(text: "Unsaved changes", tint: DesignSystem.Colors.warning)
                    }
                }

                if let docId = record.id {
                    Text("Document ID: \(docId)")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                if isEditing {
                    Button("Save") {
                        endInlineEditing()
                        onSave()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                if showConfirmDelete {
                    Button("Confirm Delete") {
                        onDelete(record)
                        showConfirmDelete = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button("Cancel") {
                        showConfirmDelete = false
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Delete") {
                        showConfirmDelete = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
    }

    private var fieldsSection: some View {
        let promptOrder: [String] = {
            if isLoadingPrompts {
                return []
            }
            return fetchedPrompts.map { $0.field }.filter { $0.lowercased() != "name" }
        }()
        let fieldKeys = displayedFields.map(\.key)
        
        let allRecordFields = fieldKeys.filter { $0.lowercased() != "name" }
        
        let orderedFields: [String] = {
            var ordered = promptOrder.filter { key in
                displayedFields.contains(where: { $0.key == key })
            }
            let remainingFields = allRecordFields.filter { !ordered.contains($0) }
            ordered.append(contentsOf: remainingFields)
            return ordered
        }()
        
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(orderedFields, id: \.self) { key in
                if let value = value(forFieldKey: key) {
                    fieldView(for: key, value: value)
                }
            }
        }
    }

    private func fieldView(for key: String, value fieldValue: String) -> some View {
        let fieldKey = key
        let editorFocus = RecordEditorFocus.field(fieldKey)
        let heightBinding = Binding(
            get: { fieldHeights[fieldKey] ?? 60 },
            set: { fieldHeights[fieldKey] = $0 }
        )

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fieldKey.capitalized)
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                if activeEditor == editorFocus {
                    formattingToolbar
                }
                Button(action: { copyField(fieldKey) }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.purple)
                }
            }
            if activeEditor == editorFocus {
                RichTextDocumentView(
                    storedText: Binding(
                    get: { value(forFieldKey: fieldKey) ?? fieldValue },
                    set: { newValue in
                        updateFieldValue(for: fieldKey, value: newValue)
                        isEditing = true
                    }
                ),
                    height: heightBinding,
                    isEditable: true,
                    shouldFocus: activeEditor == editorFocus,
                    onFocusChange: { isFocused, textView in
                        handleEditorFocusChange(isFocused, focus: editorFocus, textView: textView)
                    },
                    onFormattingChange: { state, textView in
                        activeTextView = textView
                        formattingState = state
                    }
                )
                .frame(minHeight: heightBinding.wrappedValue, maxHeight: heightBinding.wrappedValue)
                .padding(8)
                .background(DesignSystem.Colors.inputBackground)
                .cornerRadius(DesignSystem.Radius.md)
                .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.md).stroke(DesignSystem.Colors.inputBorder, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
            } else {
                RichTextDocumentView(
                    storedText: .constant(value(forFieldKey: fieldKey) ?? fieldValue),
                    height: heightBinding,
                    isEditable: false
                )
                    .allowsHitTesting(false)
                    .frame(minHeight: heightBinding.wrappedValue, maxHeight: heightBinding.wrappedValue, alignment: .topLeading)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.Colors.inputBackground)
                    .cornerRadius(DesignSystem.Radius.md)
                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.md).stroke(DesignSystem.Colors.inputBorder, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                    .onTapGesture {
                        beginInlineEditing(editorFocus)
                    }
            }
        }
    }

    private var userNotesSection: some View {
        detailSectionCard(title: "User Notes") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Spacer()
                    if activeEditor == .notes {
                        formattingToolbar
                    }
                    Button(action: copyNotes) {
                        Image(systemName: "doc.on.doc").foregroundColor(.purple)
                    }
                }

                if activeEditor == .notes {
                    RichTextDocumentView(
                        storedText: $editedNotes,
                        height: $notesHeight,
                        isEditable: true,
                        shouldFocus: activeEditor == .notes,
                        onFocusChange: { isFocused, textView in
                            handleEditorFocusChange(isFocused, focus: .notes, textView: textView)
                        },
                        onFormattingChange: { state, textView in
                            activeTextView = textView
                            formattingState = state
                        }
                    )
                        .frame(minHeight: notesHeight, maxHeight: notesHeight)
                        .padding(8)
                        .background(DesignSystem.Colors.inputBackground)
                        .cornerRadius(DesignSystem.Radius.md)
                        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.md).stroke(DesignSystem.Colors.inputBorder, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                        .onChange(of: editedNotes) { _ in isEditing = true }
                } else {
                    RichTextDocumentView(
                        storedText: .constant(editedNotes),
                        height: $notesHeight,
                        isEditable: false
                    )
                        .allowsHitTesting(false)
                        .frame(minHeight: notesHeight, maxHeight: notesHeight, alignment: .topLeading)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.Colors.inputBackground)
                        .cornerRadius(DesignSystem.Radius.md)
                        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.md).stroke(DesignSystem.Colors.inputBorder, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                        .onTapGesture {
                            beginInlineEditing(.notes)
                        }
                }
            }
        }
    }

    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let promptIdsUsed = record.promptIdsUsed, !promptIdsUsed.isEmpty {
                detailSectionCard(title: "Prompts Used") {
                    // Try to match prompt IDs with actual prompts
                    let matchedPrompts = promptIdsUsed.compactMap { id in
                        dataManager.prompts.first { $0.id == id }
                    }
                    
                    if !matchedPrompts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(matchedPrompts, id: \.id) { prompt in
                                HStack {
                                    Text("• \(prompt.field)")
                                        .font(.subheadline)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                    if !prompt.tags.isEmpty {
                                        HStack(spacing: 4) {
                                            ForEach(prompt.tags, id: \.self) { tag in
                                                Text(tag)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple.opacity(0.3))
                                                    .foregroundColor(.white.opacity(0.8))
                                                    .cornerRadius(3)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Fallback: show IDs if prompts not found
                        Text("\(promptIdsUsed.count) prompt(s) used")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .italic()
                    }
                }
            }
        }
    }

    private func detailSectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                content()
            }
        }
    }

    private var formattingToolbar: some View {
        RichTextFormattingToolbar(
            formattingState: formattingState,
            onBold: { applyFormatting(.bold) },
            onItalic: { applyFormatting(.italic) },
            onUnderline: { applyFormatting(.underline) }
        )
    }
    
    private func copyField(_ key: String) {
        let value = value(forFieldKey: key) ?? ""
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let attributedString = RichTextStorage.attributedString(from: value)
        pasteboard.writeObjects([attributedString])
    }

    private func value(forFieldKey key: String) -> String? {
        displayedFields.first(where: { $0.key == key })?.value
    }

    private func updateFieldValue(for key: String, value: String) {
        if let index = editedFields.firstIndex(where: { $0.key == key }) {
            editedFields[index].value = value
            return
        }

        editedFields.append(RecordField(key: key, value: value))
    }

    private func endInlineEditing() {
        activeTextView?.window?.makeFirstResponder(nil)
        activeTextView = nil
        activeEditor = nil
        formattingState = RichTextFormattingState()
    }
    
    private func copyNotes() {
        let value = editedNotes
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let attributedString = RichTextStorage.attributedString(from: value)
        pasteboard.writeObjects([attributedString])
    }

    private func beginInlineEditing(_ focus: RecordEditorFocus) {
        activeEditor = focus
    }

    private func handleEditorFocusChange(_ isFocused: Bool, focus: RecordEditorFocus, textView: NSTextView) {
        if isFocused {
            activeEditor = focus
            activeTextView = textView
            formattingState = textView.wr_formattingState()
            return
        }

        guard !preserveEditorFocus else {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
            return
        }

        if activeEditor == focus {
            activeEditor = nil
        }
        if activeTextView === textView {
            activeTextView = nil
        }
    }

    private func applyFormatting(_ action: RichTextFormattingAction) {
        guard let activeTextView else {
            return
        }

        preserveEditorFocus = true
        switch action {
        case .bold:
            activeTextView.wr_toggleBold()
        case .italic:
            activeTextView.wr_toggleItalic()
        case .underline:
            activeTextView.wr_toggleUnderline()
        }
        formattingState = activeTextView.wr_formattingState()

        DispatchQueue.main.async {
            activeTextView.window?.makeFirstResponder(activeTextView)
            preserveEditorFocus = false
        }
    }
}

private enum RichTextFormattingAction {
    case bold
    case italic
    case underline
}

private struct RichTextFormattingToolbar: View {
    let formattingState: RichTextFormattingState
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            toolbarChip(label: "B", isActive: formattingState.isBold, action: onBold)
            toolbarChip(label: "I", isActive: formattingState.isItalic, isItalic: true, action: onItalic)
            toolbarChip(label: "U", isActive: formattingState.isUnderlined, isUnderlined: true, action: onUnderline)
        }
    }

    private func toolbarChip(
        label: String,
        isActive: Bool,
        isItalic: Bool = false,
        isUnderlined: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        ZStack {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .rotationEffect(.degrees(isItalic ? -10 : 0))

            if isUnderlined {
                Rectangle()
                    .fill(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .frame(width: 10, height: 1)
                    .offset(y: 6)
            }
        }
        .frame(width: 24, height: 24)
        .background(isActive ? DesignSystem.Colors.selectedBackground : LinearGradient(colors: [DesignSystem.Colors.inputBackground, DesignSystem.Colors.inputBackground], startPoint: .leading, endPoint: .trailing))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isActive ? DesignSystem.Colors.selectedBorder : DesignSystem.Colors.inputBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

private struct RichTextDocumentView: NSViewRepresentable {
    @Binding var storedText: String
    @Binding var height: CGFloat
    let isEditable: Bool
    var shouldFocus: Bool = false
    var onFocusChange: ((Bool, NSTextView) -> Void)? = nil
    var onFormattingChange: ((RichTextFormattingState, NSTextView) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = RichTextTextView()
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.importsGraphics = false
        textView.isRichText = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = .zero
        textView.typingAttributes = [
            .font: RichTextStorage.baseFont,
            .foregroundColor: NSColor.white
        ]

        scrollView.documentView = textView
        context.coordinator.configure(textView: textView, with: storedText, editable: isEditable)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? RichTextTextView else {
            return
        }

        context.coordinator.parent = self
        context.coordinator.configure(textView: textView, with: storedText, editable: isEditable)
        context.coordinator.updateHeight(for: textView)

        if shouldFocus, textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextDocumentView
        private var isApplyingProgrammaticChange = false
        private var lastStoredText = ""

        init(parent: RichTextDocumentView) {
            self.parent = parent
        }

        func configure(textView: RichTextTextView, with storedText: String, editable: Bool) {
            textView.isEditable = editable
            textView.isSelectable = editable

            guard storedText != lastStoredText || textView.string.isEmpty else {
                return
            }

            isApplyingProgrammaticChange = true
            textView.textStorage?.setAttributedString(RichTextStorage.attributedString(from: storedText))
            textView.typingAttributes = [
                .font: RichTextStorage.baseFont,
                .foregroundColor: NSColor.white
            ]
            lastStoredText = storedText
            isApplyingProgrammaticChange = false
            updateHeight(for: textView)
            parent.onFormattingChange?(textView.wr_formattingState(), textView)
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? RichTextTextView else {
                return
            }

            parent.onFocusChange?(true, textView)
            parent.onFormattingChange?(textView.wr_formattingState(), textView)
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? RichTextTextView else {
                return
            }

            parent.onFocusChange?(false, textView)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? RichTextTextView else {
                return
            }

            syncStoredText(from: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? RichTextTextView else {
                return
            }

            parent.onFormattingChange?(textView.wr_formattingState(), textView)
        }

        private func syncStoredText(from textView: RichTextTextView) {
            guard !isApplyingProgrammaticChange else {
                return
            }

            let newStoredText = RichTextStorage.storedString(from: textView.attributedString())
            if newStoredText != lastStoredText {
                lastStoredText = newStoredText
                DispatchQueue.main.async {
                    self.parent.storedText = newStoredText
                }
            }
            updateHeight(for: textView)
            parent.onFormattingChange?(textView.wr_formattingState(), textView)
        }

        func updateHeight(for textView: RichTextTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                return
            }

            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let measuredHeight = max(44, ceil(usedRect.height + (textView.textContainerInset.height * 2) + 8))

            if abs(parent.height - measuredHeight) > 1 {
                DispatchQueue.main.async {
                    self.parent.height = measuredHeight
                }
            }
        }
    }
}

private final class RichTextTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == .command,
              let shortcut = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch shortcut {
        case "b":
            wr_toggleBold()
            return true
        case "i":
            wr_toggleItalic()
            return true
        case "u":
            wr_toggleUnderline()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

private extension NSTextView {
    func wr_toggleBold() {
        wr_toggleFontTrait(.boldFontMask)
    }

    func wr_toggleItalic() {
        wr_toggleFontTrait(.italicFontMask)
    }

    func wr_toggleUnderline() {
        let currentRange = selectedRange()

        if currentRange.length > 0 {
            let shouldEnableUnderline = !RichTextStorage.formattingState(for: attributedString(), selectedRange: currentRange).isUnderlined
            textStorage?.beginEditing()
            if shouldEnableUnderline {
                textStorage?.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: currentRange)
            } else {
                textStorage?.removeAttribute(.underlineStyle, range: currentRange)
            }
            textStorage?.endEditing()
        } else {
            var attributes = typingAttributes
            let underlineValue = (attributes[.underlineStyle] as? Int) ?? 0
            if underlineValue == 0 {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                attributes.removeValue(forKey: .underlineStyle)
            }
            typingAttributes = attributes
        }

        didChangeText()
    }

    func wr_formattingState() -> RichTextFormattingState {
        RichTextStorage.formattingState(for: attributedString(), selectedRange: selectedRange())
    }

    private func wr_toggleFontTrait(_ trait: NSFontTraitMask) {
        let currentRange = selectedRange()

        if currentRange.length > 0 {
            textStorage?.beginEditing()
            textStorage?.enumerateAttribute(.font, in: currentRange, options: []) { value, range, _ in
                let currentFont = (value as? NSFont) ?? RichTextStorage.baseFont
                let updatedFont = wr_font(byToggling: trait, from: currentFont)
                textStorage?.addAttribute(.font, value: updatedFont, range: range)
            }
            textStorage?.endEditing()
        } else {
            var attributes = typingAttributes
            let currentFont = (attributes[.font] as? NSFont) ?? RichTextStorage.baseFont
            attributes[.font] = wr_font(byToggling: trait, from: currentFont)
            attributes[.foregroundColor] = NSColor.white
            typingAttributes = attributes
        }

        didChangeText()
    }

    private func wr_font(byToggling trait: NSFontTraitMask, from font: NSFont) -> NSFont {
        let manager = NSFontManager.shared
        let currentTraits = manager.traits(of: font)
        let isBold = currentTraits.contains(.boldFontMask)
        let isItalic = currentTraits.contains(.italicFontMask)

        let targetBold = trait == .boldFontMask ? !isBold : isBold
        let targetItalic = trait == .italicFontMask ? !isItalic : isItalic
        return RichTextStorage.editorFont(size: max(font.pointSize, RichTextStorage.baseFontSize), bold: targetBold, italic: targetItalic)
    }
}
