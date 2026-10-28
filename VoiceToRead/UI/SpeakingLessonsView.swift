import SwiftUI
import UIKit

@MainActor
struct SpeakingLessonLibraryView: View {
    @State private var lessons: [SpeakingLesson] = []
    @State private var failed = false
    var body: some View {
        List {
            ForEach(lessons) { lesson in
                NavigationLink {
                    SpeakingLessonView(lesson: lesson)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        SpeakingLessonCover(lesson: lesson).frame(maxWidth: 280)
                        Text(verbatim: lesson.title.en).font(.headline)
                        Text(verbatim: lesson.title.es).foregroundStyle(.secondary)
                        Text("\(lesson.level) · \(lesson.estimatedMinutes) min").font(.caption)
                    }
                }.accessibilityIdentifier("guidedLesson-" + lesson.id)
            }
            if failed {
                Text("The guided lessons could not be opened. Your trainings are unchanged.")
                Button("Retry") { load() }
            }
        }
        .navigationTitle("Guided lessons").navigationBarTitleDisplayMode(.inline)
        .task { if lessons.isEmpty { load() } }
    }
    private func load() {
        do { lessons = try SpeakingLessonCatalog.load(); failed = false }
        catch { failed = true }
    }
}

private struct SpeakingLessonCover: View {
    let lesson: SpeakingLesson
    private var local: UIImage? {
        guard let url = Bundle.main.url(forResource: lesson.id + "-cover", withExtension: "png", subdirectory: "SpeakingLessons") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    var body: some View {
        Group {
            if let local { Image(uiImage: local).resizable().scaledToFill() }
            else if let asset = lesson.image.assetUrl, let url = URL(string: asset) {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { placeholder }
            } else { placeholder }
        }
        .frame(maxWidth: .infinity).aspectRatio(16 / 9, contentMode: .fit)
        .clipped().clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore).accessibilityLabel(Text(verbatim: lesson.image.altEs))
    }
    private var placeholder: some View {
        Rectangle().fill(Color.secondary.opacity(0.12))
            .overlay { Image(systemName: "book.closed").font(.largeTitle).foregroundStyle(.secondary) }
    }
}

@MainActor
private struct SpeakingLessonView: View {
    let lesson: SpeakingLesson
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var narrator = StoryNarrator()
    @State private var playingParagraph: Int?
    @State private var slow = true
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    var body: some View {
        ScrollViewReader { scroll in
            List {
                Section {
                    SpeakingLessonCover(lesson: lesson)
                    Text(verbatim: lesson.title.en).font(.title2.bold())
                    Text(verbatim: lesson.title.es).foregroundStyle(.secondary)
                    Text(verbatim: "\(lesson.level) · \(lesson.id) · \(lesson.lessonCard.language)").font(.caption)
                    Button("Begin reading", systemImage: "book") { withAnimation { scroll.scrollTo("lessonPartA", anchor: .top) } }
                        .buttonStyle(.borderedProminent).frame(minHeight: 44).accessibilityIdentifier("beginGuidedReading")
                    DisclosureGroup("Topic and objectives") {
                        Text(verbatim: lesson.mainTopic.en)
                        Text(verbatim: lesson.mainTopic.es).foregroundStyle(.secondary)
                        ForEach(lesson.learningObjectives.indices, id: \.self) { i in Text(verbatim: lesson.learningObjectives[i]) }
                    }
                }
                Section {
                    Toggle("Slow reading", isOn: $slow).disabled(narrator.state != .idle)
                    if let message = narrator.message { Text(LocalizedStringKey(message)).foregroundStyle(.secondary) }
                }
                Section("Part A · Bilingual story") {
                    ForEach(lesson.paragraphs) { paragraph in
                        paragraphCard(paragraph).id(paragraph.number == 1 ? "lessonPartA" : "lessonParagraph-\(paragraph.number)")
                    }
                }
                Section("Part B · Grammar and expressions") {
                    DisclosureGroup("Grammar") {
                        ForEach(lesson.grammar.indices, id: \.self) { i in
                            let item = lesson.grammar[i]
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: item.name).font(.headline)
                                Text(verbatim: item.exampleEn)
                                Text(verbatim: item.explanationEs).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                    DisclosureGroup("Essential expressions") {
                        ForEach(lesson.essentialExpressions.indices, id: \.self) { i in
                            let item = lesson.essentialExpressions[i]
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: item.expressionEn).font(.headline)
                                Text(verbatim: item.meaningEs).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                }
                Section("Part C · Reading practice") {
                    ForEach(lesson.readingPractice.rounds) { round in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: "\(round.number). \(round.titleEs)").font(.headline)
                            Text(verbatim: round.instructionsEs)
                            ForEach((round.chunks ?? []).indices, id: \.self) { i in
                                if let chunk = round.chunks?[i] {
                                    Text(verbatim: chunk.segments.joined(separator: " / "))
                                        .font(.body).padding(.vertical, 6)
                                }
                            }
                        }.padding(.vertical, 4)
                    }
                }
                Section {
                    DisclosureGroup("Lesson card") { card }
                }
            }
        }
        .navigationTitle(Text(verbatim: lesson.title.en)).navigationBarTitleDisplayMode(.inline)
        .onAppear { narrator.observeInterruptions() }
        .onDisappear { narrator.close() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { narrator.stop() } }
    }
    private func paragraphCard(_ paragraph: SpeakingLesson.Paragraph) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Paragraph \(paragraph.number)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    if playingParagraph == paragraph.number && narrator.state != .idle { narrator.stop() }
                    else { playingParagraph = paragraph.number; narrator.start(text: paragraph.en, language: .english, slow: slow) }
                } label: {
                    Label(uiKey(playingParagraph == paragraph.number && narrator.state != .idle ? "Stop" : "Play"),
                          systemImage: playingParagraph == paragraph.number && narrator.state != .idle ? "stop.fill" : "play.fill")
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                }.buttonStyle(.bordered).accessibilityIdentifier("lessonPlay-\(paragraph.number)")
            }
            Text(highlight(paragraph)).font(.system(size: CGFloat(settings.captionSize * textScale), weight: settings.boldCaptions ? .bold : .regular))
                .lineSpacing(CGFloat(settings.lineSpacing)).accessibilityIdentifier("lessonEnglish-\(paragraph.number)")
            Text(verbatim: paragraph.es).font(.body).foregroundStyle(.secondary)
                .accessibilityIdentifier("lessonSpanish-\(paragraph.number)")
        }.padding(.vertical, 4)
    }
    private func highlight(_ paragraph: SpeakingLesson.Paragraph) -> AttributedString {
        var text = AttributedString(paragraph.en)
        if playingParagraph == paragraph.number, narrator.progress.text == paragraph.en,
           let spoken = narrator.progress.range, let range = Range<AttributedString.Index>(spoken, in: text) {
            text[range].backgroundColor = Color(red: 1, green: 0.9, blue: 0.4)
            text[range].foregroundColor = .black
        }
        return text
    }
    private var card: some View {
        let c = lesson.lessonCard
        return VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "\(c.number) · \(c.id)")
            Text(verbatim: c.titleEn); Text(verbatim: c.titleEs)
            Text(verbatim: "\(c.level) · \(c.language)")
            Text(verbatim: c.categoryEs); Text(verbatim: c.mainTopicEs)
            Text("\(c.paragraphCount) paragraphs")
            Text(verbatim: c.grammarTopics.joined(separator: " · "))
            Text("\(c.essentialExpressionsCount) essential expressions")
            Text(verbatim: c.activitiesEs.joined(separator: " · "))
            Text("\(c.estimatedMinutes) minutes")
        }
    }
}
