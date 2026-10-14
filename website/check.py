#!/usr/bin/env python3
"""Check generated public pages, local links and the exact deployment archive.

Run after build.py. This does not certify accessibility or verify public hosting.
"""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
import zipfile
import re

ROOT = Path(__file__).resolve().parent
DIST = ROOT / 'dist'

class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids, self.links, self.tags = set(), [], []
        self.lang = None
        self.feed(text)
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.append(tag)
        if tag == 'html':
            self.lang = attrs.get('lang')
        if 'id' in attrs:
            assert attrs['id'] not in self.ids, 'Duplicate HTML id'
            self.ids.add(attrs['id'])
        for name in ('href', 'src'):
            if name in attrs:
                self.links.append(attrs[name])
        if tag == 'img':
            assert 'alt' in attrs, 'Image without an alt attribute'

pages = {p: Page(p.read_text()) for p in DIST.rglob('*.html')}
assert len(pages) == 10, 'Expected five pages in each language'
for path, page in pages.items():
    assert page.lang in ('es', 'en')
    assert page.tags.count('h1') == 1 and page.tags.count('main') == 1
    assert not any(t in page.tags for t in ('script', 'iframe', 'form'))
    for link in page.links:
        ref = urlsplit(link)
        if ref.scheme or ref.netloc:
            continue
        target = (DIST / unquote(ref.path).lstrip('/')) if ref.path.startswith('/') else path.parent / unquote(ref.path)
        if not ref.path:
            target = path
        elif target.is_dir():
            target /= 'index.html'
        target = target.resolve()
        assert target.is_relative_to(DIST.resolve()) and target.is_file(), f'Broken link: {path}: {link}'
        if ref.fragment:
            assert unquote(ref.fragment) in pages[target].ids, f'Broken anchor: {link}'
    text = path.read_text()
    for heading in re.findall(r'<h2[^>]*>(.*?)</h2>', text, re.DOTALL):
        assert '\n' not in heading and len(heading) < 150, 'Paragraph incorrectly included in heading'
    assert 'dariofernandomeneses@gmail.com' in text
    assert not any(x in text for x in ('PENDING', 'Publication draft', 'Editorial references', 'VoiceInView', 'vReader'))
    if path.parent.name == 'privacy':
        assert '90' in text and 'Hostinger' in text and 'Gmail' in text

with zipfile.ZipFile(ROOT / 'VoiceToRead-Hostinger.zip') as archive:
    expected = {str(p.relative_to(DIST)) for p in DIST.rglob('*') if p.is_file()}
    assert set(archive.namelist()) == expected
    for name in archive.namelist():
        assert archive.read(name) == (DIST / name).read_bytes()
print('PASS: 10 pages, both languages, HTML landmarks, assets, internal links/anchors and deployment ZIP.')
