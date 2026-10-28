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
    var altText: String? = nil
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
        .accessibilityElement(children: .ignore).accessibilityLabel(Text(verbatim: altText ?? lesson.image.altEs))
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
    @State private var narrator = GuidedLessonAudio()
    @AppStorage("guidedLessonSupportLocale") private var supportLocale = CaptureLanguage.spanish.rawValue
    @State private var support: GuidedLessonSupport?
    @State private var mode: GuidedLessonAudio.Mode = .understand
    @State private var repeatParagraph = true
    @State private var showTranslation = true
    private var supportLanguage: CaptureLanguage {
        let value = CaptureLanguage(rawValue: supportLocale) ?? .spanish
        return value == .english ? .spanish : value
    }
    private func supportText(_ key: String, _ spanish: String) -> String {
        supportLanguage == .spanish ? spanish : (support?.text(key, fallback: "") ?? "")
    }
    private func loadSupport() { support = GuidedLessonSupport.load(lesson: lesson, language: supportLanguage) }
    @State private var slow = true
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    var body: some View {
        ScrollViewReader { scroll in
            List {
                Section {
                    SpeakingLessonCover(lesson: lesson, altText: supportText("image.alt_es", lesson.image.altEs))
                    Text(verbatim: lesson.title.en).font(.title2.bold())
                    Text(verbatim: supportText("title.es", lesson.title.es)).foregroundStyle(.secondary)
                    Text(verbatim: "\(lesson.level) · \(lesson.id)").font(.caption)
                    Button("Begin reading", systemImage: "book") { withAnimation { scroll.scrollTo("lessonPartA", anchor: .top) } }
                        .buttonStyle(.borderedProminent).frame(minHeight: 44).accessibilityIdentifier("beginGuidedReading")
                    DisclosureGroup("Topic and objectives") {
                        Text(verbatim: lesson.mainTopic.en)
                        Text(verbatim: supportText("main_topic.es", lesson.mainTopic.es)).foregroundStyle(.secondary)
                        ForEach(lesson.learningObjectives.indices, id: \.self) { i in Text(verbatim: supportText("learning_objectives.\(i)", lesson.learningObjectives[i])) }
                    }
                }
                practiceControls
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
                                Text(verbatim: supportText("grammar.\(i).explanation_es", item.explanationEs)).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                    DisclosureGroup("Essential expressions") {
                        ForEach(lesson.essentialExpressions.indices, id: \.self) { i in
                            let item = lesson.essentialExpressions[i]
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: item.expressionEn).font(.headline)
                                Text(verbatim: supportText("essential_expressions.\(i).meaning_es", item.meaningEs)).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                }
                Section("Part C · Reading practice") {
                    ForEach(lesson.readingPractice.rounds) { round in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: "\(round.number). \(supportText("reading_practice.rounds.\(round.number - 1).title_es", round.titleEs))").font(.headline)
                            Text(verbatim: supportText("reading_practice.rounds.\(round.number - 1).instructions_es", round.instructionsEs))
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
        .safeAreaInset(edge: .bottom) {
            if narrator.active {
                HStack {
                    Group {
                        if narrator.waiting { Text("Your turn to repeat") }
                        else { Text("Playing paragraph \(narrator.paragraph ?? 0)") }
                    }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    Button(uiKey(narrator.paused ? "Resume" : "Pause")) { narrator.togglePause() }
                        .disabled(narrator.waiting).frame(minHeight: 44)
                    Button("Stop", systemImage: "stop.fill") { narrator.stop() }
                        .frame(minHeight: 44).accessibilityIdentifier("guidedStopPlayback")
                }.padding(.horizontal).background(.regularMaterial)
            }
        }
        .onAppear { narrator.observeInterruptions(); loadSupport() }
        .onChange(of: supportLocale) { _, _ in narrator.stop(); loadSupport() }
        .onChange(of: mode) { _, _ in narrator.stop() }
        .onDisappear { narrator.close() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { narrator.stop() } }
    }
    private var practiceControls: some View {
Section {
                    LanguagePickerControl(title: "Support language", selection: Binding(
                        get: { supportLanguage }, set: { supportLocale = $0.rawValue }),
                        choices: CaptureLanguage.allCases.filter { $0 != .english }, showRole: true)
                        .accessibilityIdentifier("guidedSupportLanguage")
                    if supportLanguage != .spanish {
                        Text(uiKey(support == nil ? "Support translation unavailable. Choose another language." : "Support translations generated by AI."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("Practice mode", selection: $mode) {
                        Text("Understand").tag(GuidedLessonAudio.Mode.understand)
                        Text("Listen and repeat").tag(GuidedLessonAudio.Mode.repeatPhrase)
                        Text("Shadowing").tag(GuidedLessonAudio.Mode.shadowing)
                    }.accessibilityIdentifier("guidedPracticeMode")
                    Text(uiKey(mode == .understand ? "Read the English text and consult the translation." : mode == .repeatPhrase ? "Listen, then repeat during the silent interval." : "Speak just behind the voice while the audio continues. Imitate its rhythm and intonation."))
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Playback speed", selection: $slow) {
                        Text("Slow · 0.85×").tag(true)
                        Text("Normal · 1×").tag(false)
                    }.pickerStyle(.segmented).disabled(narrator.active).accessibilityIdentifier("guidedPlaybackSpeed")
                    Toggle("Show translation", isOn: $showTranslation).accessibilityIdentifier("guidedShowTranslation")
                    if mode != .understand {
                        Toggle("Repeat paragraph", isOn: $repeatParagraph).disabled(narrator.active)
                            .accessibilityIdentifier("guidedRepeatParagraph")
                    }
                    Text("AI-generated voice by OpenAI · Marin").font(.caption).foregroundStyle(.secondary)
                    if let message = narrator.message { Text(LocalizedStringKey(message)).foregroundStyle(.secondary) }
                }
    }

    private func paragraphCard(_ paragraph: SpeakingLesson.Paragraph) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Paragraph \(paragraph.number)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    if narrator.paragraph == paragraph.number { narrator.stop() }
                    else { narrator.start(lesson: lesson, paragraph: paragraph, slow: slow, mode: mode, repeating: repeatParagraph) }
                } label: {
                    Label(uiKey(narrator.paragraph == paragraph.number ? "Stop" : "Play"),
                          systemImage: narrator.paragraph == paragraph.number ? "stop.fill" : "play.fill")
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                }.buttonStyle(.bordered).accessibilityIdentifier("lessonPlay-\(paragraph.number)")
            }
            Text(highlight(paragraph)).font(.system(size: CGFloat(settings.captionSize * textScale), weight: settings.boldCaptions ? .bold : .regular))
                .lineSpacing(CGFloat(settings.lineSpacing)).accessibilityIdentifier("lessonEnglish-\(paragraph.number)")
            if showTranslation {
                Text(verbatim: supportText("paragraphs.\(paragraph.number - 1).es", paragraph.es)).font(.body).foregroundStyle(.secondary)
                    .accessibilityIdentifier("lessonSpanish-\(paragraph.number)")
            }
        }.padding(.vertical, 4)
    }
    private func highlight(_ paragraph: SpeakingLesson.Paragraph) -> AttributedString {
        var text = AttributedString(paragraph.en)
        if narrator.paragraph == paragraph.number,
           let spoken = narrator.range, let range = Range<AttributedString.Index>(spoken, in: text) {
            text[range].backgroundColor = Color(red: 1, green: 0.9, blue: 0.4)
            text[range].foregroundColor = .black
        }
        return text
    }
    private var card: some View {
        let c = lesson.lessonCard
        return VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "\(c.number) · \(c.id)")
            Text(verbatim: c.titleEn); Text(verbatim: supportText("lesson_card.title_es", c.titleEs))
            Text(verbatim: "\(c.level) · \(supportText("lesson_card.language", c.language))")
            Text(verbatim: supportText("lesson_card.category_es", c.categoryEs)); Text(verbatim: supportText("lesson_card.main_topic_es", c.mainTopicEs))
            Text("\(c.paragraphCount) paragraphs")
            Text(verbatim: c.grammarTopics.joined(separator: " · "))
            Text("\(c.essentialExpressionsCount) essential expressions")
            Text(verbatim: c.activitiesEs.indices.map { supportText("lesson_card.activities_es.\($0)", c.activitiesEs[$0]) }.joined(separator: " · "))
            Text("\(c.estimatedMinutes) minutes")
        }
    }
}
