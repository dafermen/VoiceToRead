"""Validate all bundled lesson resources, then publish the explicit eighty-ID catalog."""
from pathlib import Path
import json,hashlib,re,sys,struct
r=Path(__file__).resolve().parents[1];folder=r/'VoiceToRead/Resources/SpeakingLessons'
ids=[f'SPK-{level}-{n:03}' for level in ['B1','B2','C1','C2'] for n in range(1,21)]
content_only='--content-only' in sys.argv
assert not (content_only and '--publish' in sys.argv),'Publication requires complete audio and support validation'
titles_by_level={
'B1':['Improving My English','My Daily Routine','At the Doctor’s Office','A Job Interview','My First Day at a New Job'],
'B2':['Improving My English','My Daily Routine','At the Doctor’s Office','A Job Interview','My First Day at a New Job'],
'C1':['Improving My English','A Job Interview','Resolving a Conflict','Defending a Proposal','Discussing Social Change'],
'C2':['Improving My English','A Job Interview','Mediating a Negotiation','An Ethical Dilemma','Disagreeing with Tact']
}
new_titles=['Travel Plans and Unexpected Changes','Finding a Place to Live','Shopping and Solving a Problem','Friendship and Difficult Conversations','Technology in Everyday Life']
new_titles.extend(['Ordering Food at a Restaurant','Finding My Way Around a City','Planning a Celebration','Learning a New Skill','Helping in My Community','Owning a Mistake and Making It Right','Choosing a Course','Planning a Day Outdoors','Working Together on a Deadline','Setting Goals for My Future'])
for titles in titles_by_level.values():titles.extend(new_titles)

def support_fields(value,path=''):
 result={}
 if isinstance(value,dict):
  for k,v in value.items():result.update(support_fields(v,f'{path}.{k}' if path else k))
 elif isinstance(value,list):
  for i,v in enumerate(value):result.update(support_fields(v,f'{path}.{i}'))
 elif isinstance(value,str) and (path.endswith(('.es','_es')) or path.startswith('learning_objectives.') or path.startswith('lesson_card.activities_es.') or path=='lesson_card.language'):result[path]=value
 return result
alltext=set();bytes_audio=0;audio_count=0;cover_hashes=set()
for identifier in ids:
 d=json.loads((folder/(identifier+'.json')).read_text(encoding='utf-8'));level=identifier.split('-')[1];n=int(identifier[-3:])
 assert d['id']==identifier and d['level']==level and d['number']==n
 assert d['title']['en']==titles_by_level[level][n-1] and d['language']=='en-US'
 cover=(folder/(identifier+'-cover.png')).read_bytes()
 assert cover[:8]==b'\x89PNG\r\n\x1a\n'
 width,height=struct.unpack('>II',cover[16:24]);assert height>0 and abs(width/height-16/9)<0.025
 fingerprint=hashlib.sha256(cover).hexdigest();assert fingerprint not in cover_hashes;cover_hashes.add(fingerprint)
 c=d['lesson_card']
 assert c['id']==d['id'] and c['level']==level and int(c['number'])==n
 assert c['title_en']==d['title']['en'] and c['title_es']==d['title']['es']
 assert c['paragraph_count']==20 and c['essential_expressions_count']==8 and c['estimated_minutes']==d['estimated_minutes']
 assert d['schema_version']=='1.0.0' and d['status']=='ready'
 assert [p['number'] for p in d['paragraphs']]==list(range(1,21))
 assert len(d['grammar'])==8 and len(d['essential_expressions'])==8
 assert [x['number'] for x in d['reading_practice']['rounds']]==[1,2,3]
 assert d['lesson_card']['grammar_topics']==[g['name'] for g in d['grammar']]
 assert d['lesson_card']['activities_es']==[x['title_es'] for x in d['reading_practice']['rounds']]
 for item in d['grammar']+d['essential_expressions']:
  assert 1<=item['source_paragraph']<=20
 if level in ['C1','C2'] or n>=6:
  for item in d['grammar']:assert item['example_en']==d['paragraphs'][item['source_paragraph']-1]['en']
  for item in d['essential_expressions']:assert item['expression_en'].lower() in d['paragraphs'][item['source_paragraph']-1]['en'].lower()
 for rnd in d['reading_practice']['rounds']:
  for chunk in rnd.get('chunks',[]):
   assert 1<=chunk['source_paragraph']<=20 and all(chunk['segments'])
   if identifier!='SPK-B1-001':assert ' '.join(chunk['segments'])==d['paragraphs'][chunk['source_paragraph']-1]['en']
 current=tuple(p['en'] for p in d['paragraphs']);assert current not in alltext;alltext.add(current)
 if content_only:
  assert len(d['learning_objectives'])==5
  assert all(p['en'].strip() and p['es'].strip() for p in d['paragraphs'])
  if n>=11:assert all(2<=len(e['expression_en'].split())<=8 for e in d['essential_expressions'])
  print(identifier+': lesson content and cover validated; audio/support not checked.',flush=True)
  continue
 directory=folder/(identifier+'-audio');manifest=json.loads((directory/'manifest.json').read_text())
 assert manifest['lesson']==identifier and manifest['voice']=='marin' and manifest['base_speed']==0.85 and len(manifest['paragraphs'])==20
 for p,m in zip(d['paragraphs'],manifest['paragraphs']):
  audio=directory/f"{p['number']:02}.mp3";timing=json.loads((directory/f"{p['number']:02}.json").read_text(encoding='utf-8'))
  assert hashlib.sha256(audio.read_bytes()).hexdigest()==m['sha256']
  assert hashlib.sha256(p['en'].encode()).hexdigest()==m['text_sha256'] and timing['text']==p['en']
  tokens=re.findall(r"\w+(?:['’]\w+)*",p['en']);assert len(tokens)==len(timing['words'])
  last=0
  for token,word in zip(tokens,timing['words']):
   source=p['en'].encode('utf-16-le');start=word['location']*2;end=start+word['length']*2
   assert source[start:end].decode('utf-16-le')==token
   assert last<=word['start']<=word['end']<=timing['duration']+0.1
   last=word['start']
  bytes_audio+=audio.stat().st_size;audio_count+=1
 for locale in ['fr','ko','ja','zh-Hans']:
  pack=json.loads((folder/f'{identifier}-support-{locale}.json').read_text(encoding='utf-8'))
  assert pack['lesson']==identifier and pack['locale']==locale
  assert set(pack['strings'])==set(support_fields(d))
  assert all(isinstance(v,str) and v.strip() for v in pack['strings'].values())
 print(identifier+': content, audio, word ranges and support packs validated.',flush=True)
assert hashlib.sha256((folder/'SPK-B1-001.json').read_text(encoding='utf-8').encode('utf-8')).hexdigest()=='ef501c0449ffce48a4d88bbbd9a83a8c39476c6f93226cc71d486a7013587cd0'
assert not list(folder.rglob('*-review.json')),'Review files must be resolved before publication'
assert not list(folder.rglob('.env*'))
if '--publish' in sys.argv:(folder/'catalog.json').write_text(json.dumps(ids,indent=2)+'\n',encoding='utf-8')
if content_only:print('PASS: eighty lesson texts and distinct covers; audio/support not checked, catalog NOT published.',flush=True)
else:print(f'PASS: eighty complete lessons; {audio_count} audios ({bytes_audio/1024/1024:.1f} MiB); three hundred twenty support packs; eighty distinct covers; original 001 unchanged.',flush=True)
