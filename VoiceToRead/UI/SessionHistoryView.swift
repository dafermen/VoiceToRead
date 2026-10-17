import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

@MainActor
struct SessionHistoryView: View {
    let coordinator: SessionCoordinator
    var recoveryOnly = false
    var favoritesOnly = false
    var showsFilters = true
    @Query(sort: \ConferenceSession.createdAt, order: .reverse) private var sessions: [ConferenceSession]
    @Query private var reviews: [SessionReview]
    @Query private var drafts: [SessionDraft]
    @Query private var translations: [SessionTranslation]
    @Query private var favorites: [SessionFavorite]
    @Query private var trash: [SessionTrash]
    @Query private var languagePairs: [SessionLanguagePair]
    @Query private var media: [SessionMedia]
    @State private var lastDeletedID: UUID?
    @State private var onlyFavorites = false
    @State private var actionsSessionID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var unprotecting: ConferenceSession?
    @State private var query = ""
    @State private var deleting: ConferenceSession?
    @State private var failure: String?

    private func matches(_ session: ConferenceSession) -> [ReviewParagraph] {
        let changes = (try? reviews.first(where: { $0.sessionID == session.id })?.decodedCorrections()) ?? [:]
        let originals = session.orderedCaptions.map { ReviewParagraph(id: $0.id, text: $0.text) }
        let english = TranscriptReview.paragraphs(originals: originals, corrections: changes)
        let snapshot = try? translations.first(where: { $0.sessionID == session.id })?.decoded()
        let spanish = snapshot?.isCurrent(english) == true ? snapshot?.translated ?? [] : []
        return (english + spanish).filter { $0.text.localizedStandardContains(query) }
    }
    private var recoverySessions: [ConferenceSession] {
        sessions.filter { session in drafts.contains { $0.sessionID == session.id } && !trash.contains { $0.sessionID == session.id } }
    }
    private var filtered: [ConferenceSession] {
        let visible = sessions.filter { session in
            !trash.contains { $0.sessionID == session.id } &&
            drafts.contains { $0.sessionID == session.id } == recoveryOnly
        }
        let sessions = (onlyFavorites || favoritesOnly) ? visible.filter { isFavorite($0) } : visible
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedStandardContains(query) || !matches($0).isEmpty }
    }

    private var days: [Date] {
        Array(Set(filtered.map { Calendar.current.startOfDay(for: $0.createdAt) })).sorted(by: >)
    }

    var body: some View {
        List {
            if let id = lastDeletedID, trash.contains(where: { $0.sessionID == id }), let lastDeleted = sessions.first(where: { $0.id == id }) {
                HStack {
                    Text("Moved to Recently deleted")
                    Spacer()
                    Button("Undo") {
                        do { try coordinator.repository.restore(lastDeleted); self.lastDeletedID = nil }
                        catch { failure = error.localizedDescription }
                    }.accessibilityIdentifier("undoSessionDeletion")
                }
            }
            if !recoveryOnly && showsFilters {
                Picker("Show sessions", selection: $onlyFavorites) {
                    Text("All sessions").tag(false)
                    Text("Favorites").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("sessionFavoritesFilter")
                if !recoverySessions.isEmpty && !onlyFavorites && query.isEmpty {
                    NavigationLink {
                        SessionHistoryView(coordinator: coordinator, recoveryOnly: true)
                    } label: {
                        Label("Unsaved drafts: \(recoverySessions.count) · Review", systemImage: "doc.badge.clock")
                            .font(.subheadline)
                    }.accessibilityIdentifier("reviewDraftsLink")
                }
            }
            if filtered.isEmpty {
                if !query.isEmpty { ContentUnavailableView.search(text: query) }
                else if recoveryOnly {
                    ContentUnavailableView("No recovery drafts", systemImage: "doc.badge.clock",
                        description: Text("Unfinished recordings will appear here."))
                } else if onlyFavorites || favoritesOnly {
                    ContentUnavailableView("No favorites", systemImage: "star",
                        description: Text("Protect a saved session to find it here."))
                } else {
                    ContentUnavailableView("No sessions", systemImage: "text.bubble",
                        description: Text("Saved sessions will appear here."))
                }
            }
            if recoveryOnly {
                Section {
                    Text("Saved automatically for recovery. Choose Save to keep a session or Discard to delete its text and audio.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(filtered) { session in
                        sessionLink(session)
                        HStack {
                            Button("Save Session", systemImage: "square.and.arrow.down") { saveDraft(session) }
                                .accessibilityIdentifier("saveDraft-" + session.id.uuidString)
                            Spacer()
                            Button("Discard", systemImage: "trash", role: .destructive) { deleting = session }
                                .accessibilityIdentifier("discardDraft-" + session.id.uuidString)
                        }.buttonStyle(.borderless)
                            .disabled(coordinator.currentSession?.id == session.id && coordinator.caption.state != .ended)
                    }
                }
            } else {
                ForEach(days, id: \.self) { day in
                    Section {
                        ForEach(filtered.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: day) }) { session in sessionLink(session) }
                    } header: {
                        if Calendar.current.isDateInToday(day) { Text("Today") }
                        else if Calendar.current.isDateInYesterday(day) { Text("Yesterday") }
                        else { Text(day, style: .date) }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search titles or content")
        .navigationTitle(uiKey(recoveryOnly ? "Recovery drafts" : favoritesOnly ? "Favorites" : "Sessions"))
        .toolbar {
            if !recoveryOnly && showsFilters {
                Menu {
                    NavigationLink { SessionHistoryView(coordinator: coordinator, recoveryOnly: true) } label: {
                        Label("Recovery drafts (\(recoverySessions.count))", systemImage: "doc.badge.clock")
                    }
                    NavigationLink { RecentlyDeletedView(repository: coordinator.repository) } label: {
                        Label("Recently deleted (\(trash.count))", systemImage: "trash")
                    }.accessibilityIdentifier("recentlyDeletedLink")
                } label: { Label("Session library options", systemImage: "ellipsis.circle") }
                    .accessibilityIdentifier("sessionLibraryOptions")
            }
        }
        .onChange(of: onlyFavorites) { _, _ in actionsSessionID = nil }
        .onChange(of: query) { _, _ in actionsSessionID = nil }
        .confirmationDialog(uiKey("Remove favorite protection?"), isPresented: Binding(
            get: { unprotecting != nil }, set: { if !$0 { unprotecting = nil } }), titleVisibility: .visible) {
                Button("Remove protection", role: .destructive) {
                    if let unprotecting { setFavorite(false, session: unprotecting) }
                    unprotecting = nil
                }.accessibilityIdentifier("confirmRemoveSessionProtection")
                Button("Cancel", role: .cancel) { unprotecting = nil }
            } message: { Text("The session stays saved. Deleting it later will require a separate confirmation.") }
        .confirmationDialog(uiKey("Remove this session?"), isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let deleting {
                        guard !isFavorite(deleting) else { self.deleting = nil; return }
                        do {
                            if drafts.contains(where: { $0.sessionID == deleting.id }) {
                                if coordinator.currentSession?.id == deleting.id { Task { await coordinator.discardCurrent() } }
                                else { try coordinator.repository.delete(deleting) }
                            } else {
                                coordinator.cancelAutomaticTranslation(for: deleting.id)
                                try coordinator.repository.moveToTrash(deleting)
                                lastDeletedID = deleting.id; actionsSessionID = nil
                            }
                        } catch { failure = error.localizedDescription }
                    }
                    deleting = nil
                }.accessibilityIdentifier("confirmDeleteSession")
            } message: {
                Text(uiKey(drafts.contains { $0.sessionID == deleting?.id }
                    ? "Discard permanently deletes this session's transcript and any recorded audio."
                    : "You can restore this session and its audio for 30 days in Recently deleted."))
            }
        .alert("Storage problem", isPresented: Binding(
            get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK") { failure = nil }
            } message: { Text(LocalizedStringKey(failure ?? "")) }
    }

    private func isFavorite(_ session: ConferenceSession) -> Bool { favorites.contains { $0.sessionID == session.id } }
    private func setFavorite(_ enabled: Bool, session: ConferenceSession) {
        do { try coordinator.repository.setFavorite(enabled, for: session) }
        catch { failure = "Could not update favorite protection. Please try again." }
    }

    private func saveDraft(_ session: ConferenceSession) {
        if coordinator.currentSession?.id == session.id {
            _ = coordinator.saveCurrent(ended: true)
        } else {
            do { try coordinator.repository.publish(session) }
            catch { failure = "The draft could not be saved. Please retry." }
        }
    }

    /// A horizontal gesture only reveals actions: deleting always needs a separate tap and confirmation.
    /// The actions button and VoiceOver actions offer the same path without requiring a swipe.
    private func sessionLink(_ session: ConferenceSession) -> some View {
        HStack(spacing: 8) {
        NavigationLink {
            SessionDetailView(session: session, repository: coordinator.repository,
                canEdit: coordinator.currentSession?.id != session.id || coordinator.caption.state == .ended,
                canPlay: !coordinator.caption.state.active && !coordinator.caption.state.busy &&
                    (coordinator.currentSession?.id != session.id || coordinator.caption.state == .ended),
                initialSearch: query)
        } label: {
            VStack(alignment: .leading) {
                Text(session.title).font(.headline)
                if isFavorite(session) { Label("Protected favorite", systemImage: "star.fill").font(.caption) }
                if !query.isEmpty, let match = matches(session).first {
                    Text(match.text).font(.subheadline).lineLimit(3)
                }
                let source = CaptureLanguage(rawValue: session.language) ?? .english
                let target = languagePairs.first { $0.sessionID == session.id }.flatMap { CaptureLanguage(rawValue: $0.targetLocale) } ?? source.defaultTarget
                Text(verbatim: source.name + " → " + target.name).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(session.createdAt, style: .time)
                    if media.contains(where: { $0.sessionID == session.id && $0.audioName != nil }) {
                        Label("Recorded audio", systemImage: "waveform").labelStyle(.iconOnly)
                    }
                }.font(.caption)
                (session.endedAt == nil ? Text("Unfinished or interrupted session") : Text(verbatim: SessionClock.format(session.duration))).font(.caption)
            }
        }
        .accessibilityIdentifier("sessionRow-" + session.id.uuidString)
        if actionsSessionID == session.id {
            let draft = drafts.contains { $0.sessionID == session.id }
            Button {
                toggleProtection(session)
            } label: {
                Image(systemName: isFavorite(session) ? "lock.fill" : "star")
                    .font(.title3.weight(.semibold)).foregroundStyle(.black)
                    .frame(width: 48, height: 48).background(.yellow, in: Circle())
            }
            .buttonStyle(.plain).disabled(draft)
            .accessibilityLabel(uiKey(isFavorite(session) ? "Remove protection" : "Favorite & protect"))
            .accessibilityHint(uiKey(draft ? "Save the draft before protecting it." : "Favorites protect the session and its audio."))
            .accessibilityIdentifier("protectSessionAction")
            Button {
                requestDeletion(session)
            } label: {
                Image(systemName: "trash")
                    .font(.title3.weight(.semibold)).foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(canDelete(session) ? Color.red : Color.gray, in: Circle())
            }
            .buttonStyle(.plain).disabled(!canDelete(session))
            .accessibilityLabel("Delete")
            .accessibilityHint(uiKey(isFavorite(session) ? "Remove protection before deleting the session or its audio." : "Requires confirmation."))
            .accessibilityIdentifier("deleteSessionAction")
        } else {
            Button { revealActions(session.id) } label: {
                Label("Session actions", systemImage: "ellipsis.circle").labelStyle(.iconOnly)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.borderless)
                .accessibilityIdentifier("sessionActions-" + session.id.uuidString)
        }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 25).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
            if value.translation.width < -40 { revealActions(session.id) }
            else if value.translation.width > 40 { revealActions(nil) }
        })
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            Button("Session actions") { revealActions(session.id) }
            if !drafts.contains(where: { $0.sessionID == session.id }) {
                Button(uiKey(isFavorite(session) ? "Remove protection" : "Favorite & protect")) { toggleProtection(session) }
            }
            if canDelete(session) {
                Button("Delete") { requestDeletion(session) }
            }
        }
    }
    private func revealActions(_ id: UUID?) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { actionsSessionID = id }
    }
    private func toggleProtection(_ session: ConferenceSession) {
        guard !drafts.contains(where: { $0.sessionID == session.id }) else { return }
        if isFavorite(session) { unprotecting = session }
        else { setFavorite(true, session: session) }
    }
    private func canDelete(_ session: ConferenceSession) -> Bool {
        !isFavorite(session) && !(coordinator.currentSession?.id == session.id && coordinator.caption.state != .ended)
    }
    private func requestDeletion(_ session: ConferenceSession) {
        guard canDelete(session) else { return }
        deleting = session
    }

}

@MainActor
struct SessionDetailView: View {
    @Bindable var session: ConferenceSession
    let repository: TranscriptRepository
    let canEdit: Bool
    let canPlay: Bool
    var initialSearch: String
    @Query private var favorites: [SessionFavorite]
    @State private var removingProtection = false
    @State private var isDraft = true
    private var protected: Bool { favorites.contains { $0.sessionID == session.id } }
    @State private var showingMedia = false
    @State private var playbackParagraphID: UUID?
    @State private var playableParagraphIDs: Set<UUID> = []
    @Query private var reviews: [SessionReview]
    @State private var showingTranslation = false
    @State private var showingLearning = false
    @State private var showingEditor = false
    @State private var showingShare = false
    @State private var renaming = false
    @State private var title = ""
    @State private var failure: String?
    @State private var position: UUID?
    @State private var restored = false
    @State private var savePositionTask: Task<Void, Never>?

    init(session: ConferenceSession, repository: TranscriptRepository, canEdit: Bool, canPlay: Bool = true, initialSearch: String = "") {
        self.session = session
        self.repository = repository
        self.canEdit = canEdit
        self.canPlay = canPlay
        self.initialSearch = initialSearch
        let identifier = session.id
        _reviews = Query(filter: #Predicate<SessionReview> { $0.sessionID == identifier })
    }

    private var originals: [ReviewParagraph] { session.orderedCaptions.map { ReviewParagraph(id: $0.id, text: $0.text) } }
    private var corrections: [String: String]? {
        do { return try reviews.first?.decodedCorrections() ?? [:] } catch { return nil }
    }
    private var paragraphs: [ReviewParagraph] {
        TranscriptReview.paragraphs(originals: originals, corrections: corrections ?? [:])
    }

    private func refreshPlayableParagraphs() {
        playableParagraphIDs = []
        guard canPlay, let url = try? repository.audioURL(for: session.id),
              FileManager.default.fileExists(atPath: url.path),
              let media = try? repository.media(for: session.id),
              let timings = try? media.decodedTimings() else { return }
        playableParagraphIDs = Set(SubtitleExport.cues(paragraphs: paragraphs, timings: timings).map(\.paragraphID))
    }

    @ViewBuilder private func paragraphView(_ paragraph: ReviewParagraph, index: Int) -> some View {
        if canPlay && playableParagraphIDs.contains(paragraph.id) && !paragraph.text.isEmpty {
            Button {
                playbackParagraphID = paragraph.id
                showingMedia = true
            } label: {
                Text(paragraph.text).font(.title2).foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Listen from this paragraph")
            .accessibilityIdentifier("listenParagraph-\(index)")
        } else {
            (paragraph.text.isEmpty ? Text("Empty paragraph") : Text(verbatim: paragraph.text))
                .font(.title2).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("reviewParagraph-\(index)")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.createdAt, style: .date)
                    Text("\(SessionClock.format(session.duration)) · \(session.language)")
                    if !canEdit { Text("Stop this session in Captions before editing.") }
                    else if session.endedAt == nil { Text("Saved final captions from an unfinished session.") }
                    if !(corrections ?? [:]).isEmpty { Label("Edited transcript", systemImage: "pencil").font(.caption) }
                }.font(.subheadline).foregroundStyle(.secondary)
                if !isDraft {
                    Button(uiKey(protected ? "Protected favorite" : "Favorite & protect"), systemImage: protected ? "star.fill" : "star") {
                        if protected { removingProtection = true }
                        else {
                            do { try repository.setFavorite(true, for: session) }
                            catch { failure = "Could not update favorite protection. Please try again." }
                        }
                    }.accessibilityIdentifier("favoriteSessionButton")
                    if protected { Text("Remove protection before deleting the session or its audio.").font(.caption) }
                }
                Button("Audio & subtitles", systemImage: "waveform") { playbackParagraphID = nil; showingMedia = true }
                    .disabled(!canPlay || corrections == nil).accessibilityIdentifier("sessionMediaButton")
                Button("Text & translation", systemImage: "character.bubble") { showingTranslation = true }
                    .disabled(!canEdit || !canPlay || corrections == nil || paragraphs.isEmpty)
                    .accessibilityIdentifier("sessionTranslationButton")
                Button("Practicar idioma", systemImage: "book") { showingLearning = true }
                    .disabled(!canEdit || !canPlay || corrections == nil || paragraphs.isEmpty)
                    .accessibilityIdentifier("learnEnglishButton")
                if !canPlay { Text("Stop listening before opening audio and subtitles.").font(.caption) }
                if corrections == nil {
                    ContentUnavailableView("Corrections unavailable", systemImage: "exclamationmark.triangle",
                        description: Text("Reopen this session. Your original captions have not been changed."))
                } else {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(paragraphs.enumerated()), id: \.element.id) { index, paragraph in
                            VStack(alignment: .leading, spacing: 4) {
                                paragraphView(paragraph, index: index)

                            }.id(paragraph.id)
                        }
                    }.scrollTargetLayout()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollPosition(id: $position, anchor: .top)
        .accessibilityIdentifier("sessionReader")
        .navigationTitle(session.title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(session.title) { title = session.title; renaming = true }
                    .font(.headline).lineLimit(1).accessibilityLabel("Rename session")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Edit transcript", systemImage: "pencil") { showingEditor = true }
                    .disabled(!canEdit || corrections == nil || originals.isEmpty)
                    .accessibilityIdentifier("editTranscriptButton")
                Button("Review & share", systemImage: "square.and.arrow.up") { showingShare = true }
                    .disabled(corrections == nil).accessibilityIdentifier("reviewShareButton")
            }
        }
        .task(id: showingMedia) { refreshPlayableParagraphs() }
        .task { isDraft = (try? repository.draft(for: session.id)) != nil }
        .confirmationDialog(uiKey("Remove favorite protection?"), isPresented: $removingProtection, titleVisibility: .visible) {
            Button("Remove protection", role: .destructive) {
                do { try repository.setFavorite(false, for: session) }
                catch { failure = "Could not update favorite protection. Please try again." }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The session stays saved. Deleting it later will require a separate confirmation.") }
        .sheet(isPresented: $showingMedia) {
            SessionMediaView(session: session, repository: repository, paragraphs: paragraphs,
                             hasCorrections: !(corrections ?? [:]).isEmpty, initialParagraphID: playbackParagraphID)
        }
        .sheet(isPresented: $showingLearning) {
            EnglishLearningView(session: session, repository: repository)
        }
        .sheet(isPresented: $showingTranslation) {
            SessionTranslationView(session: session, repository: repository, searchQuery: initialSearch)
        }
        .sheet(isPresented: $showingEditor) {
            TranscriptEditorView(originals: originals, reviewed: paragraphs) { edited in
                guard canEdit else { throw ReviewFailure.sessionChanged }
                try repository.saveCorrections(edited, for: session)
            }
        }
        .sheet(isPresented: $showingShare) {
            TranscriptShareView(session: session, repository: repository, canEdit: canEdit)
        }
        .alert("Rename session", isPresented: $renaming) {
            TextField("Title", text: $title)
            Button("Save") {
                do { try repository.rename(session, title: title) }
                catch { failure = "The session could not be renamed." }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Storage problem", isPresented: Binding(
            get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK") { failure = nil }
            } message: { Text(LocalizedStringKey(failure ?? "")) }
        .task {
            guard !restored else { return }
            do {
                position = try repository.review(for: session.id)?.lastReadCaptionID
                if !initialSearch.isEmpty {
                    if let match = paragraphs.first(where: { $0.text.localizedStandardContains(initialSearch) }) {
                        position = match.id
                    } else if canPlay, let translation = try repository.translation(for: session.id)?.decoded(),
                              translation.isCurrent(paragraphs),
                              translation.translated.contains(where: { $0.text.localizedStandardContains(initialSearch) }) {
                        showingTranslation = true
                    }
                }
            }
            catch { failure = "Could not restore your reading position." }
            restored = true
        }
        .onChange(of: position) { _, _ in
            guard restored else { return }
            savePositionTask?.cancel()
            savePositionTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                persistPosition()
            }
        }
        .onDisappear {
            savePositionTask?.cancel()
            persistPosition()
        }
    }

    private func persistPosition() {
        guard restored, let position else { return }
        do { try repository.saveReadingPosition(position, for: session) }
        catch { failure = "Could not save your reading position. Your transcript is unchanged." }
    }
}

/// Recovery is explicit and preserves every original file. Permanent deletion is confirmed separately.
@MainActor
struct RecentlyDeletedView: View {
    let repository: TranscriptRepository
    @Query(sort: \ConferenceSession.createdAt, order: .reverse) private var sessions: [ConferenceSession]
    @Query private var trash: [SessionTrash]
    @State private var deleting: ConferenceSession?
    @State private var failure: String?
    var body: some View {
        List {
            Text("Sessions and audio remain on this device for 30 days. Expired items are permanently removed when the app opens. Restore them or delete them permanently here.")
                .font(.callout)
            if trash.isEmpty { Text("No deleted sessions") }
            ForEach(sessions.filter { session in trash.contains { $0.sessionID == session.id } }) { session in
                VStack(alignment: .leading, spacing: 12) {
                    Text(session.title).font(.headline)
                    if let marker = trash.first(where: { $0.sessionID == session.id }) {
                        Text("Recovery deadline").font(.caption)
                        Text(marker.expiresAt, style: .date).font(.caption)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack { actions(session) }
                        VStack(alignment: .leading) { actions(session) }
                    }.buttonStyle(.borderless)
                }.padding(.vertical, 6)
            }
        }.navigationTitle("Recently deleted")
            .task { do { try repository.purgeExpiredTrash() } catch { failure = error.localizedDescription } }
            .confirmationDialog("Delete this session permanently?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete permanently", role: .destructive) {
                    if let deleting { do { try repository.delete(deleting) } catch { failure = error.localizedDescription } }
                    deleting = nil
                }.accessibilityIdentifier("permanentlyDeleteSession")
                Button("Cancel", role: .cancel) { deleting = nil }
            } message: { Text("This permanently deletes the transcript and any audio from this session.") }
            .alert("Storage problem", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK") { failure = nil }
            } message: { Text(LocalizedStringKey(failure ?? "")) }
    }
    @ViewBuilder private func actions(_ session: ConferenceSession) -> some View {
        Button("Restore", systemImage: "arrow.uturn.backward") {
            do { try repository.restore(session) } catch { failure = error.localizedDescription }
        }.accessibilityIdentifier("restoreDeletedSession")
        Button("Delete permanently", systemImage: "trash", role: .destructive) { deleting = session }
    }
}

@MainActor
struct SessionLibraryView: View {
    let coordinator: SessionCoordinator
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var category: String? = "saved"
    @Query private var drafts: [SessionDraft]
    @Query private var trash: [SessionTrash]
    var body: some View {
        if sizeClass == .regular {
            NavigationSplitView {
                List(selection: $category) {
                    Label("Saved sessions", systemImage: "text.bubble").tag("saved")
                    Label("Favorites", systemImage: "star").tag("favorites")
                    Label("Recovery drafts (\(drafts.count))", systemImage: "doc.badge.clock").tag("drafts")
                    Label("Recently deleted (\(trash.count))", systemImage: "trash").tag("trash")
                }.navigationTitle("Sessions")
            } detail: {
                NavigationStack {
                    if category == "trash" { RecentlyDeletedView(repository: coordinator.repository) }
                    else {
                        SessionHistoryView(coordinator: coordinator, recoveryOnly: category == "drafts",
                            favoritesOnly: category == "favorites", showsFilters: false).id(category)
                    }
                }
            }
        } else { NavigationStack { SessionHistoryView(coordinator: coordinator) } }
    }
}
