import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit
import UIKit

@MainActor
struct TranscriptShareView: View {
    let session: ConferenceSession
    let repository: TranscriptRepository
    let canEdit: Bool
    @Query private var reviews: [SessionReview]
    @Environment(\.dismiss) private var dismiss
    @State private var originals: [ReviewParagraph]
    @State private var format: ExportFormat = .text
    @State private var includeDetails = true
    @State private var prepared: Data?
    @State private var preparedRequest: ExportRequest?
    @State private var preparing = false
    @State private var failure: String?
    @State private var showingEditor = false
    @State private var savingFile = false
    @State private var sharedFile: SharedTranscriptFile?
    @State private var temporaryURL: URL?
    @State private var copied = false

    init(session: ConferenceSession, repository: TranscriptRepository, canEdit: Bool) {
        self.session = session
        self.repository = repository
        self.canEdit = canEdit
        let identifier = session.id
        _reviews = Query(filter: #Predicate<SessionReview> { $0.sessionID == identifier })
        _originals = State(initialValue: session.orderedCaptions.map { ReviewParagraph(id: $0.id, text: $0.text) })
    }

    private var corrections: [String: String]? {
        do { return try reviews.first?.decodedCorrections() ?? [:] } catch { return nil }
    }
    private var paragraphs: [ReviewParagraph] {
        guard let corrections else { return [] }
        return TranscriptReview.paragraphs(originals: originals, corrections: corrections)
    }
    private var bodyText: String {
        guard let corrections else { return "" }
        return TranscriptReview.text(TranscriptReview.paragraphs(originals: originals, corrections: corrections))
    }
    private var exportTitle: String { session.title }
    private var exportText: String {
        TranscriptExport.render(title: exportTitle, date: session.startedAt, duration: session.duration,
            language: session.language, transcript: bodyText, unfinished: session.endedAt == nil, includeDetails: includeDetails)
    }
    private var request: ExportRequest { ExportRequest(text: exportText, format: format, includeDetails: includeDetails) }
    private var hasText: Bool { !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && corrections != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    HStack {
                        Picker("Format", selection: $format) {
                            Text("TXT").tag(ExportFormat.text)
                            Text("PDF").tag(ExportFormat.pdf)
                        }.pickerStyle(.segmented).frame(maxWidth: 160)
                        Toggle("Session details", isOn: $includeDetails).font(.subheadline)
                    }
                    if !canEdit { Text("This preview contains saved captions so far. Stop the session in Captions to edit it.").font(.caption).foregroundStyle(.secondary) }
                }.padding()
                Divider()
                preview.frame(maxWidth: .infinity, maxHeight: .infinity)
                if let failure { Text(LocalizedStringKey(failure)).font(.caption).foregroundStyle(.red).padding(.horizontal) }
                Divider()
                HStack {
                    Button(uiKey(copied ? "Copied" : "Copy"), systemImage: copied ? "checkmark" : "doc.on.doc") {
                        UIPasteboard.general.string = exportText
                        copied = true
                    }
                    Spacer()
                    Button("Save file", systemImage: "folder") { savingFile = true }
                    Spacer()
                    Button("Share", systemImage: "square.and.arrow.up") { share() }
                }
                .font(.subheadline).frame(minHeight: 50).padding(.horizontal)
                .disabled(prepared == nil || preparedRequest != request || preparing || !hasText)
            }
            .navigationTitle("Review & share").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { DoneButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit", systemImage: "pencil") { showingEditor = true }
                        .disabled(!canEdit || corrections == nil).accessibilityIdentifier("editFromPreview")
                }
            }
            .task(id: request) { await prepare() }
            .sheet(isPresented: $showingEditor) {
                TranscriptEditorView(originals: originals, reviewed: paragraphs) { edited in
                    guard canEdit else { throw ReviewFailure.sessionChanged }
                    try repository.saveCorrections(edited, for: session)
                }
            }
            .fileExporter(isPresented: $savingFile, document: TranscriptFileDocument(data: prepared ?? Data()),
                          contentType: format.contentType, defaultFilename: TranscriptExport.filename(title: exportTitle)) { result in
                if case .failure = result { failure = "The file could not be saved. Try again." }
            }
            .sheet(item: $sharedFile, onDismiss: { removeTemporaryFile() }) { file in
                TranscriptActivitySheet(url: file.url)
            }
            .onDisappear { if sharedFile == nil { removeTemporaryFile() } }
        }
    }

    @ViewBuilder private var preview: some View {
        if corrections == nil {
            ContentUnavailableView("Corrections unavailable", systemImage: "exclamationmark.triangle",
                description: Text("Reopen the session before sharing. Your original captions have not been changed."))
        } else if !hasText {
            ContentUnavailableView("No text to share", systemImage: "text.bubble",
                description: Text("This transcript is empty."))
        } else if preparing || preparedRequest != request {
            ProgressView(uiKey(format == .pdf ? "Preparing PDF" : "Preparing preview"))
        } else if format == .pdf, let prepared {
            TranscriptPDFPreview(data: prepared).accessibilityIdentifier("pdfPreview")
        } else {
            ScrollView {
                Text(exportText).font(.body).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding()
                    .accessibilityIdentifier("exportPreviewText")
            }
        }
    }

    private func prepare() async {
        prepared = nil
        preparedRequest = nil
        failure = nil
        copied = false
        guard hasText else { preparing = false; return }
        preparing = true
        let current = request
        do {
            let data: Data
            if current.format == .pdf {
                let task = Task.detached(priority: .userInitiated) {
                    try TranscriptPDF.render(text: current.text, emphasizeTitle: current.includeDetails)
                }
                data = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
            } else { data = Data(current.text.utf8) }
            try Task.checkCancellation()
            guard current == request else { return }
            prepared = data
            preparedRequest = current
            preparing = false
        } catch is CancellationError { /* A newer preview owns the loading state. */ }
        catch { preparing = false; failure = error.localizedDescription }
    }

    private func share() {
        guard let prepared, preparedRequest == request else { return }
        do {
            removeTemporaryFile()
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceToRead-share-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            let url = folder.appendingPathComponent(TranscriptExport.filename(title: exportTitle)).appendingPathExtension(format == .pdf ? "pdf" : "txt")
            temporaryURL = url
            try prepared.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            sharedFile = SharedTranscriptFile(url: url)
        } catch { removeTemporaryFile(); failure = "The file could not be prepared for sharing. Try again." }
    }

    private func removeTemporaryFile() {
        if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL.deletingLastPathComponent()) }
        temporaryURL = nil
    }
}

private enum ExportFormat: Hashable, Sendable {
    case text, pdf
    var contentType: UTType { self == .pdf ? .pdf : .plainText }
}
private struct ExportRequest: Hashable, Sendable {
    let text: String
    let format: ExportFormat
    let includeDetails: Bool
}
private struct SharedTranscriptFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct TranscriptActivitySheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.view.accessibilityIdentifier = "transcriptShareSheet"
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct TranscriptPDFPreview: UIViewRepresentable {
    let data: Data
    final class Coordinator { var data: Data? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .secondarySystemBackground
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        guard context.coordinator.data != data else { return }
        context.coordinator.data = data
        view.document = PDFDocument(data: data)
    }
}
