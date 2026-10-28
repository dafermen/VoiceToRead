from pathlib import Path
import urllib.request,urllib.error,json,hashlib,re,unicodedata,uuid,sys,shutil
root=Path(__file__).resolve().parents[1]; folder=root/'VoiceToRead/Resources/SpeakingLessons'
lesson=json.loads((folder/'SPK-B1-001.json').read_text(encoding='utf-8'))
out=folder/'SPK-B1-001-audio';out.mkdir(exist_ok=True)
key=next((line.partition('=')[2].strip().strip('"').strip("'") for line in (root/'.env').read_text(encoding='utf-8-sig').splitlines() if line.partition('=')[0].strip()=='OPENAI_API_KEY'),None)
if not key:sys.exit('Missing local API key (not printed).')
def request(path,data,ctype):
 req=urllib.request.Request('https://api.openai.com/v1/'+path,data=data,headers={'Authorization':'Bearer '+key,'Content-Type':ctype},method='POST')
 try:
  with urllib.request.urlopen(req,timeout=180) as response:return response.read()
 except urllib.error.HTTPError as e:sys.exit('OpenAI HTTP '+str(e.code)+'; stopped without logging credentials.')
def normal(s):return ''.join(c for c in unicodedata.normalize('NFKD',s).lower() if c.isalnum())
def transcribe(path,text):
 boundary=uuid.uuid4().hex;parts=[]
 for name,value in [('model','whisper-1'),('language','en'),('response_format','verbose_json'),('timestamp_granularities[]','word'),('prompt',text)]:
  parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
 parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="paragraph.mp3"\r\nContent-Type: audio/mpeg\r\n\r\n'.encode()+path.read_bytes()+b'\r\n')
 parts.append(f'--{boundary}--\r\n'.encode())
 return json.loads(request('audio/transcriptions',b''.join(parts),'multipart/form-data; boundary='+boundary))
manifest=[]
for p in lesson['paragraphs']:
 n=p['number'];text=p['en'];path=out/f'{n:02}.mp3';timestamps=out/f'{n:02}.json'
 if not path.exists():
  sample=Path(__file__).resolve().parents[1]/'local-voice-preview/paragraph-01-marin-speed085.mp3'
  if n==1 and sample.exists():shutil.copyfile(sample,path)
  else:
   payload={'model':'gpt-4o-mini-tts','voice':'marin','input':text,'speed':0.85,'response_format':'mp3','instructions':'Read the provided text verbatim in clear, natural American English for an adult B1 language learner. Warm, calm teaching voice. Slightly slower than normal conversation, with natural phrasing and intonation. Do not exaggerate sounds, do not add words, introductions, music or sound effects.'}
   data=request('audio/speech',json.dumps(payload).encode(),'application/json')
   if len(data)<1000:sys.exit('Invalid audio response.')
   path.write_bytes(data)
 if not timestamps.exists():
  response=transcribe(path,text);words=response.get('words',[])
  spans=[];cursor=0
  for word in words:
   clean=normal(word['word']);spans.append((cursor,cursor+len(clean),float(word['start']),float(word['end'])));cursor+=len(clean)
  if ''.join(normal(w['word']) for w in words)!=normal(text):
   (out/f'{n:02}-review.json').write_text(json.dumps(response,ensure_ascii=False,indent=2),encoding='utf-8')
   sys.exit(f'Paragraph {n}: transcription differs; retained audio for review, no estimated word times.')
  cues=[];cursor=0
  for m in re.finditer(r"\w+(?:['’]\w+)*",text):
   size=len(normal(m.group()));matches=[s for s in spans if s[0]<cursor+size and s[1]>cursor]
   if not matches:sys.exit('Missing word timing.')
   cues.append({'location':len(text[:m.start()].encode('utf-16-le'))//2,'length':len(m.group().encode('utf-16-le'))//2,'start':matches[0][2],'end':matches[-1][3]});cursor+=size
  timestamps.write_text(json.dumps({'text':text,'duration':response.get('duration'), 'words':cues},ensure_ascii=False,indent=2),encoding='utf-8')
 manifest.append({'number':n,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'text_sha256':hashlib.sha256(text.encode()).hexdigest()})
 print(f'Paragraph {n:02}: audio and verified word timestamps ready.',flush=True)
(out/'manifest.json').write_text(json.dumps({'lesson':'SPK-B1-001','voice':'marin','model':'gpt-4o-mini-tts','base_speed':0.85,'ai_generated':True,'paragraphs':manifest},indent=2),encoding='utf-8')
print('All twenty offline audio assets completed.',flush=True)
