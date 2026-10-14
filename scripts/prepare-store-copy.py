#!/usr/bin/env python3
"""Generate copyable store fields and a local handoff ZIP; this does not submit to Apple."""
import json
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / 'docs/app-store-metadata.json').read_text())
output = root / 'build/app-store'
output.mkdir(parents=True, exist_ok=True)
for locale, fields in data['localizations'].items():
    text = '\n\n'.join(f'{key}\n{fields[key]}' for key in
                      ('name', 'subtitle', 'keywords', 'description', 'privacyPolicyURL', 'supportURL'))
    (output / f'{locale}.txt').write_text(text + '\n')
# Always replace the archive rather than append stale screenshots from older runs.
with zipfile.ZipFile(output / 'VoiceToRead-AppStore-1.0.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(output.glob('*.txt')):
        archive.write(path, 'copy/' + path.name)
    for relative in ('docs/store/submission-kit.md', 'docs/store/review-notes.md',
                     'docs/app-store-metadata.json', 'docs/release-checklist.md'):
        archive.write(root / relative, relative)
    for path in sorted((root / 'docs/store/screenshots').rglob('*')):
        if path.is_file():
            archive.write(path, str(path.relative_to(root)))
print(output / 'VoiceToRead-AppStore-1.0.zip')
print('Prepared for review only; inspect outstanding requirements before submission.')
