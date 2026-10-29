"""Validate bundled podcasts before publishing their explicit catalog."""
from pathlib import Path
import json,hashlib,re,struct,subprocess,sys
r=Path(__file__).resolve().parents[1];folder=r/'VoiceToRead/Resources/Podcasts';ids=['POD-B1B2-001'];total=0
for identifier in ids:
 episode=json.loads((folder/(identifier+'.json')).read_text(encoding='utf-8'));assert episode['schemaVersion']==1 and episode['id']==identifier
 assert episode['language']=='en-US' and episode['baseSpeed']==.85 and all(episode[k].strip() for k in ['titleEn','titleEs','summaryEn','summaryEs'])
 assert [s['number'] for s in episode['segments']]==list(range(1,31))
 directory=folder/(identifier+'-audio');manifest=json.loads((directory/'manifest.json').read_text())
 assert manifest['episode']==identifier and manifest['voice']=='marin' and manifest['base_speed']==.85 and manifest['ai_generated'] and len(manifest['segments'])==30
 seconds=0
 for segment,entry in zip(episode['segments'],manifest['segments']):
  assert segment['en'].strip() and segment['es'].strip() and segment['number']==entry['number']
  audio=directory/f'{segment["number"]:02}.mp3';timing=json.loads((directory/f'{segment["number"]:02}.json').read_text(encoding='utf-8'))
  assert hashlib.sha256(audio.read_bytes()).hexdigest()==entry['sha256']
  assert hashlib.sha256(segment['en'].encode()).hexdigest()==entry['text_sha256'] and timing['text']==segment['en']
  assert len(timing['words'])==len(re.findall(r"\w+(?:['’]\w+)*",segment['en']))
  last=0
  for token,word in zip(re.findall(r"\w+(?:['’]\w+)*",segment['en']),timing['words']):
   source=segment['en'].encode('utf-16-le');assert source[word['location']*2:(word['location']+word['length'])*2].decode('utf-16-le')==token
   assert last<=word['start']<=word['end']<=segment['duration']+.25;last=word['start']
  probe=subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(audio)],capture_output=True,text=True,check=True)
  duration=float(json.loads(probe.stdout)['format']['duration']);assert abs(duration-segment['duration'])<.25
  seconds+=duration;total+=1
 assert 480<=seconds*episode['baseSpeed']<=720 and 480<=seconds<=720
 assert not any(re.search(r'youtube|subscribe|downloadyoutubesubtitles|https?://',s['en']+' '+s['es'],re.I) for s in episode['segments'])
 print(f'{identifier}: 30 verified bilingual fragments; normal {seconds*.85/60:.2f} min, slow {seconds/60:.2f} min.')
assert not list(folder.rglob('*-review.json'))
assert not list(folder.rglob('*.srt')) and not list(folder.rglob('.env*'))
project=(r/'VoiceToRead.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
for path in ['Models/PodcastEpisode.swift','Services/PodcastPlayback.swift','UI/PodcastsView.swift','Resources/Podcasts','PodcastTests.swift']:assert f'path = "{path}";' in project
home=(r/'VoiceToRead/UI/AppRootView.swift').read_text(encoding='utf-8').split('struct CommunicationHomeView')[1];assert 'Module.stories' not in home and 'case talk, listen, train }' in home
hub=(r/'VoiceToRead/UI/EnglishTrainingView.swift').read_text(encoding='utf-8').split('private struct PersonalTrainingLibraryView')[0]
positions=[hub.index(x) for x in ['guidedLessonsEntry','personalPracticesEntry','trainingStoriesEntry','trainingPodcastsEntry']];assert positions==sorted(positions)
if '--publish' in sys.argv:(folder/'catalog.json').write_text(json.dumps(ids,indent=2)+'\n',encoding='utf-8')
print(f'PASS: {total} audio files, exact word ranges, manifests, durations, source privacy and ordered Training navigation. Native Xcode compilation not run here.')
