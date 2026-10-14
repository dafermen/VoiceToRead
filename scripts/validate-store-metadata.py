#!/usr/bin/env python3
"""Validate store-copy lengths. --ready additionally rejects incomplete publication data.

Passing this check is not App Review approval or a substitute for device acceptance.
"""
import argparse
import json
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ready', action='store_true')
    args = parser.parse_args()
    data = json.loads((ROOT / 'docs/app-store-metadata.json').read_text())
    for locale in ('en-US', 'es-ES'):
        item = data['localizations'][locale]
        for key, limit in [('name', 30), ('subtitle', 30), ('keywords', 100),
                           ('description', 4000), ('releaseNotes', 4000)]:
            value = item[key]
            if not value.strip() or len(value) > limit:
                raise SystemExit(f'{locale}.{key}: empty or longer than {limit} characters')
        print(f'{locale}: copy length checks passed')
    pending = data.get('ownerPending', [])
    if args.ready:
        for field in ('privacyPolicyURL', 'supportURL'):
            url = urlparse(data.get(field) or '')
            if url.scheme != 'https' or not url.netloc:
                pending = pending + [field]
        if not data.get('publisher'):
            pending = pending + ['publisher']
        if pending or data.get('status', '').startswith('DRAFT'):
            raise SystemExit('Not ready for submission: ' + ', '.join(dict.fromkeys(pending or ['draft status'])))
    elif pending:
        print('Publication still pending owner data and final acceptance; see docs/app-store.md.')

if __name__ == '__main__':
    main()
