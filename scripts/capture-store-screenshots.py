#!/usr/bin/env python3
"""Run store UI checks and capture native simulator pixels (Xcode 15.2+ on macOS).

Example: python3 scripts/capture-store-screenshots.py --device UDID --label iphone
Uses only the specified simulator. Run one device at a time. No uploads, signing or real session data.
"""
import argparse
import datetime
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--device', required=True, help='Installed simulator UUID')
parser.add_argument('--label', required=True, choices=('iphone', 'ipad'))
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
run = root / 'build' / f'store-{args.label}-{stamp}'
run.mkdir(parents=True)
expected = (1179, 2556) if args.label == 'iphone' else (2048, 2732)
command = ['xcodebuild', '-project', 'VoiceToRead.xcodeproj', '-scheme', 'VoiceToRead',
           '-configuration', 'Debug', '-destination', f'platform=iOS Simulator,id={args.device}',
           '-derivedDataPath', '/private/tmp/VoiceToRead-store-prep', '-parallel-testing-enabled', 'NO',
           '-resultBundlePath', str(run / 'Tests.xcresult'),
           '-only-testing:VoiceToReadTests/HomeScreenTests/testStoreScreenshotsAndPrivacyEnglish',
           '-only-testing:VoiceToReadTests/HomeScreenTests/testStoreScreenshotsAndPrivacySpanish',
           'CODE_SIGNING_ALLOWED=NO', 'test']
# Stream Xcode's attachment events while the UI test keeps each frame stable for five seconds.
# simctl preserves native dimensions; don't resize an incorrectly sized XCTest attachment.
process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, bufsize=1)
captured = set()
with (run / 'xcodebuild.log').open('w') as log:
    for line in process.stdout:
        log.write(line); log.flush()
        match = re.search(r"Added attachment named 'Store-(en-US|es-ES)-(\d{2}-[a-z-]+)'", line)
        if match:
            locale, name = match.groups()
            folder = run / 'qa' if 'privacy-qa' in name else run / locale
            folder.mkdir(parents=True, exist_ok=True)
            output = folder / f'{locale}-{name}.jpg'
            subprocess.run(['xcrun', 'simctl', 'io', args.device, 'screenshot', '--type=jpeg', str(output)], check=True)
            dimensions = subprocess.check_output(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', str(output)], text=True)
            width = int(re.search(r'pixelWidth: (\d+)', dimensions).group(1))
            height = int(re.search(r'pixelHeight: (\d+)', dimensions).group(1))
            if (width, height) != expected:
                raise SystemExit(f'Unexpected capture size: {width}x{height}; required {expected}')
            captured.add((locale, name))
            print(output, flush=True)
        elif 'Test Case' in line or 'error:' in line:
            print(line.strip(), flush=True)
code = process.wait()
if code or len(captured) != 8:
    raise SystemExit(f'UI checks/captures incomplete: exit {code}, {len(captured)}/8. Inspect {run}')
print(f'PASS: {run}', flush=True)
