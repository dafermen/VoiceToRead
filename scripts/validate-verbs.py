"""Read-only checks for the curated catalog and its project registration; not a Swift compiler."""
import json,re
from pathlib import Path
r=Path(__file__).resolve().parents[1]
data=json.loads((r/'VoiceToRead/Resources/VerbReference/verbs.json').read_text(encoding='utf-8'))
assert len(data)==28 and len({v['base'] for v in data})==len(data)
patterns={}
for v in data:
    assert set(v)==set('base past participle thirdPerson ing meaningEs meaningEn complement regular continuous translations'.split())
    assert all(isinstance(v[k],str) and v[k].strip()==v[k] and v[k] for k in v if k not in ['regular','continuous','translations'])
    assert isinstance(v['regular'],bool) and isinstance(v['continuous'],bool)
    assert set(v['translations'])=={'en','es','fr','ko','ja','zh-Hans'}
    for lang,glosses in v['translations'].items():
        expected={'base','past','participle','third','ing','meaning'} | ({'past-was','past-were'} if v['base']=='be' else set())
        assert set(glosses)==expected,(v['base'],lang)
        assert all(isinstance(t,str) and t.strip()==t and t and '�' not in t for t in glosses.values())

    a,b,c=v['base'],v['past'],v['participle']
    group='regular' if v['regular'] else 'AAA' if a==b==c else 'ABB' if b==c else 'ABA' if a==c else 'AAB' if a==b else 'ABC'
    patterns[group]=patterns.get(group,0)+1
assert set(patterns)=={'AAA','ABB','ABC','ABA','AAB','regular'}
by={v['base']:v for v in data}
assert by['beat']['past']=='beat' and by['beat']['participle']=='beaten'
assert by['study']['thirdPerson']=='studies' and by['run']['ing']=='running'
assert not any(by[w]['continuous'] for w in ['be','know','see'])
assert not {'crow','snow','read'} & by.keys()
project=(r/'VoiceToRead.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
for path in ['Models/VerbConjugation.swift','UI/VerbReferenceView.swift','Resources/VerbReference','VerbConjugationTests.swift']:
    assert f'path = "{path}";' in project
for path in ['VoiceToRead/Models/VerbConjugation.swift','VoiceToRead/UI/VerbReferenceView.swift','VoiceToReadUnitTests/VerbConjugationTests.swift']:
    source=(r/path).read_text(encoding='utf-8')
    masked=re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*','',source)
    stack=[]
    for c in masked:
        if c in '({[': stack.append(c)
        elif c in ')}]': assert stack and '({['.index(stack.pop())==')}]'.index(c),path
    assert not stack,path
    assert not re.search(r'\b(URLSession|AVAudioRecorder|SFSpeechRecognizer)\b',source)
hub=(r/'VoiceToRead/UI/EnglishTrainingView.swift').read_text(encoding='utf-8')
assert hub.index('trainingVerbsEntry')>hub.index('trainingPodcastsEntry')
print('PASS: 28 complete unique verbs; six translation languages, every displayed form; pattern coverage',patterns)
print('PASS: catalog registration, Training entry order, Swift delimiters and no recording/network APIs.')
print('Native Swift compilation and XCTest remain pending on macOS.')
