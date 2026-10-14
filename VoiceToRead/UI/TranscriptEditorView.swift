import SwiftUI

@MainActor
struct TranscriptEditorView: View {
    let originals: [ReviewParagraph]
    let initial: [ReviewParagraph]
    let translation: Bool
    let save: ([ReviewParagraph]) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var history: EditHistory<[ReviewParagraph]>
    @State private var selected: ReviewParagraph?
    @State private var showingFind = false
    @State private var confirmingDiscard = false
    @State private var confirmingRestore = false
    @State private var failure: String?

    init(originals: [ReviewParagraph], reviewed: [ReviewParagraph], translation: Bool = false, save: @escaping ([ReviewParagraph]) throws -> Void) {
        self.translation = translation
        self.originals = originals
        initial = reviewed
        self.save = save
        _history = State(initialValue: EditHistory(reviewed))
    }

    private var dirty: Bool { history.value != initial }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button("Undo", systemImage: "arrow.uturn.backward") { history.undo() }
                            .disabled(!history.canUndo).accessibilityIdentifier("undoTranscriptEdit")
                        Spacer()
                        Button("Redo", systemImage: "arrow.uturn.forward") { history.redo() }
                            .disabled(!history.canRedo)
                    }
                    .buttonStyle(.borderless).frame(minHeight: 44)
                    Button("Find and replace", systemImage: "magnifyingglass") { showingFind = true }
                        .accessibilityIdentifier("findReplaceButton")
                    Button(uiKey(translation ? "Restore translation" : "Restore original"), systemImage: "clock.arrow.circlepath") { confirmingRestore = true }
                        .accessibilityIdentifier("restoreOriginalDraft")
                        .disabled(history.value == originals)
                } footer: {
                    Text(uiKey(translation ? "Edit the translation here. The source transcript stays unchanged. Restore translation returns to the machine translation." : "Tap a paragraph to correct it. Changes stay in this draft until you save. The original recognition is always kept."))
                }
                Section("Transcript") {
                    ForEach(Array(history.value.enumerated()), id: \.element.id) { index, paragraph in
                        Button { selected = paragraph } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Paragraph \(index + 1)").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Image(systemName: "pencil").font(.caption)
                                }
                                (paragraph.text.isEmpty ? Text("Empty paragraph") : Text(verbatim: paragraph.text))
                                    .foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("editParagraph-\(index)")
                    }
                }
            }
            .navigationTitle(uiKey(translation ? "Edit translation" : "Edit transcript")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if dirty { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try save(history.value); dismiss() }
                        catch { failure = error.localizedDescription }
                    }
                    .disabled(!dirty).accessibilityIdentifier("saveTranscriptEdits")
                }
            }
            .sheet(item: $selected) { paragraph in
                ParagraphEditorView(paragraph: paragraph, translation: translation) { text in
                    var edited = history.value
                    if let index = edited.firstIndex(where: { $0.id == paragraph.id }) {
                        edited[index].text = text
                        history.set(edited)
                    }
                }
            }
            .sheet(isPresented: $showingFind) {
                FindReplaceView(paragraphs: Binding(get: { history.value }, set: { history.set($0) }))
            }
            .confirmationDialog(uiKey("Discard unsaved corrections?"), isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .confirmationDialog(uiKey(translation ? "Restore the machine translation in this draft?" : "Restore the original recognition in this draft?"), isPresented: $confirmingRestore, titleVisibility: .visible) {
                Button("Restore original", role: .destructive) { history.set(originals) }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Could not save corrections", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK") { failure = nil }
            } message: { Text(LocalizedStringKey(failure ?? "")) }
        }
        .interactiveDismissDisabled(dirty)
    }
}

@MainActor
struct ParagraphEditorView: View {
    let paragraph: ReviewParagraph
    let apply: (String) throws -> Void
    var savesImmediately = false
    var translation = false
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss
    @State private var history: EditHistory<String>
    @FocusState private var focused: Bool
    @State private var confirmingDiscard = false

    init(paragraph: ReviewParagraph, savesImmediately: Bool = false, translation: Bool = false, apply: @escaping (String) throws -> Void) {
        self.savesImmediately = savesImmediately
        self.translation = translation
        self.paragraph = paragraph
        self.apply = apply
        _history = State(initialValue: EditHistory(paragraph.text))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button("Undo", systemImage: "arrow.uturn.backward") { history.undo() }.disabled(!history.canUndo)
                    Spacer()
                    Button("Redo", systemImage: "arrow.uturn.forward") { history.redo() }.disabled(!history.canRedo)
                }
                .frame(minHeight: 44).padding(.horizontal)
                TextEditor(text: Binding(get: { history.value }, set: { history.set($0) }))
                    .font(.title3).padding(.horizontal, 12).focused($focused)
                    .accessibilityLabel("Paragraph text").accessibilityIdentifier("paragraphEditor")
            }
            .navigationTitle(uiKey(translation ? "Edit translation" : "Correct paragraph")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if history.value != paragraph.text { confirmingDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(uiKey(savesImmediately ? "Save" : "Apply")) {
                        do { try apply(history.value); dismiss() }
                        catch { failure = error.localizedDescription }
                    }.accessibilityIdentifier("saveParagraphCorrection")
                }
            }
            .confirmationDialog(uiKey("Discard this paragraph's changes?"), isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .alert("Could not save corrections", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK") { failure = nil }
            } message: { Text(LocalizedStringKey(failure ?? "")) }
            .task { focused = true }
        }
        .interactiveDismissDisabled(history.value != paragraph.text)
    }
}

@MainActor
private struct FindReplaceView: View {
    @Binding var paragraphs: [ReviewParagraph]
    @Environment(\.dismiss) private var dismiss
    @State private var search = TranscriptSearch(query: "", replacement: "")
    @State private var confirmingAll = false
    private enum Field: Hashable { case find, replacement }
    @FocusState private var focused: Field?
    private var matches: [TextMatch] { search.matches(in: paragraphs) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Find", text: $search.query).accessibilityIdentifier("findText")
                        .focused($focused, equals: .find).submitLabel(.next)
                        .onSubmit { focused = .replacement }
                    TextField("Replace with", text: $search.replacement).accessibilityIdentifier("replacementText")
                        .focused($focused, equals: .replacement).submitLabel(.done)
                        .onSubmit { focused = nil }
                    Toggle("Whole words", isOn: $search.wholeWords)
                    Toggle("Match case", isOn: $search.caseSensitive)
                }
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                Section("\(matches.count) matches") {
                    if !search.query.isEmpty && matches.isEmpty { Text("No matches").foregroundStyle(.secondary) }
                    ForEach(matches.prefix(200)) { match in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(match.matched).strikethrough().foregroundStyle(.secondary)
                                Image(systemName: "arrow.right").accessibilityHidden(true)
                                (search.replacement.isEmpty ? Text("(delete)") : Text(verbatim: search.replacement)).bold()
                            }
                            .font(.subheadline)
                            Text(String(match.before.suffix(80)) + search.replacement + String(match.after.prefix(80)))
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Replace this match") { paragraphs = search.replacing(match, in: paragraphs) }
                                .buttonStyle(.borderless).frame(minHeight: 44)
                        }
                        .padding(.vertical, 4)
                    }
                    if matches.count > 200 { Text("Showing the first 200 matches. Replace all includes every match.").font(.caption) }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Find and replace").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Preview matches") { focused = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Replace all") { confirmingAll = true }.disabled(matches.isEmpty)
                }
            }
            .confirmationDialog(uiKey("Replace all \(matches.count) matches?"), isPresented: $confirmingAll, titleVisibility: .visible) {
                Button("Replace \(matches.count) matches") { paragraphs = search.replacingAll(in: paragraphs) }
                Button("Cancel", role: .cancel) {}
            } message: { Text("You can undo this change in the transcript editor.") }
        }
    }
}
