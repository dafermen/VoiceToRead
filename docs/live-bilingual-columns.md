# Live bilingual columns — 2026-11-03

In Home > Listen > Reading options, Bilingual reading offers the existing Original / Translation / Both content choices and a presentation picker. Both enables Interleaved (default) or Columns. The presentation is stored independently in `liveBilingualLayout`; changing the content choice does not erase it. This is a local display preference only.

Columns place each confirmed original on the left and its matching translation on the right, keyed by the existing paragraph UUID. One custom SwiftUI Layout measures both cells at equal widths and gives them the larger required height. Both cards share a row and one vertical ScrollView. While translation is pending, the right-hand card occupies the row height set by the original/placeholder; longer translations can still increase that height. Provisional original text also has a paired pending card. Nothing is clipped or shrunk to hold a fixed row height.

The existing language colors, contrast, bold text, line spacing and reading size are retained. Text wraps at the available width, including iPhone portrait and landscape or iPad. A short localized hint explains that landscape provides more room on phones. The preference does not add fullscreen controls. Paragraph order for accessibility remains original followed by its translation within each paired row.

The existing translation runner, queue, UUID matching, scheduling, retry behavior, capture actions and session resolution/persistence are unchanged. Changing presentation does not recreate the translation reader or clear its buffer. Existing interleaved and translation-only paragraph rendering is preserved. Switching layouts follows the existing follow-live preference; a reader browsing older paragraphs is not forced to the newest paragraph.

Checks performed on Windows: localization parity/placeholders; Xcode project references; Swift delimiters; source comparisons for unchanged translation lifecycle, scheduler, prior layouts, capture controls and session decisions. A native UI regression test covers selecting columns during capture, paired geometry, pause, fullscreen rotation, restoring interleaved with the same texts, and the final Save/Discard actions. The existing debug live-translation fixture clears the new preference so tests start deterministically without pinning a read-only launch-argument value.

Native Swift compilation, XCTest execution, iPhone/iPad visual geometry, long-text rendering and VoiceOver checks require Xcode/macOS or a device and were not run on Windows.
