# Automatic translation preparation in My practices

Opening a personal practice starts one missing-only translation job automatically. The Start
practice control remains first and becomes available when all responses are ready. A visible
phrase counter/progress bar and Cancel translation appear alongside it. A failed or cancelled
job does not loop automatically: its inline message offers Retry. Retrying a failed full
replacement asks for the existing confirmation again, rather than silently replacing edits.

Prepare translations is removed from this detail screen. Translate again is in the leading
ellipsis options menu, retains the replacement confirmation and commits only on complete
success. Review translations stays visible and optional. Saving source edits (including a
new phrase without changing languages) automatically prepares only missing responses.

Ready practices and corrected responses are never queued by automatic preparation. The
missing set uses the same whitespace rule as readiness and acceptance. Existing source-ID,
source-text, language-pair and replacement-snapshot checks remain in force. Removing a job
invalidates late callbacks. Leaving the detail screen cancels its runner without saving partial
results. This uses the existing local TranslationRunner: iOS may still ask to download language
models. No API key, new cloud service, archive format or practice-recording change is introduced.

Validation: English/Spanish catalog parity, project references and focused source checks on
Windows. The existing two XCUI flows now wait for automatic preparation without tapping a
preparation control; multilingual retranslation still checks cancellation/retained corrections.
A targeted model test covers missing-only selection, whitespace, atomic failure, corrected
responses, presentation preferences, stale callbacks and newly added source phrases. Native
Swift compilation and XCTest/XCUI execution require macOS and remain pending locally.
