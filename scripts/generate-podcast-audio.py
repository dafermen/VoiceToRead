"""Build bundled podcast speech and measured word cues using the existing offline audio pipeline."""
from pathlib import Path
import urllib.request,urllib.error,json,hashlib,re,unicodedata,uuid,sys,argparse,subprocess
parser=argparse.ArgumentParser();parser.add_argument('--episode',default='POD-B1B2-001');args=parser.parse_args()
if not re.fullmatch(r'POD-[A-Z0-9]+-\d{3}',args.episode):sys.exit('Invalid episode identifier.')
root=Path(__file__).resolve().parents[1];folder=root/'VoiceToRead/Resources/Podcasts';path=folder/(args.episode+'.json');episode=json.loads(path.read_text(encoding='utf-8'))
out=folder/(args.episode+'-audio');out.mkdir(exist_ok=True)
key=next((line.partition('=')[2].strip().strip('"').strip("'") for line in (root/'.env').read_text(encoding='utf-8-sig').splitlines() if line.partition('=')[0].strip()=='OPENAI_API_KEY'),None)
if not key:sys.exit('Missing local development key.')
def request(endpoint,data,ctype):
 req=urllib.request.Request('https://api.openai.com/v1/'+endpoint,data=data,headers={'Authorization':'Bearer '+key,'Content-Type':ctype},method='POST')
 try:
  with urllib.request.urlopen(req,timeout=180) as response:return response.read()
 except urllib.error.HTTPError as e:sys.exit('OpenAI HTTP '+str(e.code)+'; credentials not logged.')
def normal(s):return ''.join(c for c in unicodedata.normalize('NFKD',s).lower() if c.isalnum())
def transcribe(audio,text):
 boundary=uuid.uuid4().hex;parts=[]
 for name,value in [('model','whisper-1'),('language','en'),('response_format','verbose_json'),('timestamp_granularities[]','word'),('prompt',text)]:parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
 parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="segment.mp3"\r\nContent-Type: audio/mpeg\r\n\r\n'.encode()+audio.read_bytes()+b'\r\n');parts.append(f'--{boundary}--\r\n'.encode())
 return json.loads(request('audio/transcriptions',b''.join(parts),'multipart/form-data; boundary='+boundary))
manifest=[]
for segment in episode['segments']:
 n=segment['number'];text=segment['en'];audio=out/f'{n:02}.mp3';timing=out/f'{n:02}.json'
 if timing.exists() and json.loads(timing.read_text(encoding='utf-8'))['text']!=text:sys.exit('Source changed; explicit regeneration is required.')
 if not audio.exists():
  payload={'model':'gpt-4o-mini-tts','voice':'marin','input':text,'speed':episode['baseSpeed'],'response_format':'mp3','instructions':'Read this text verbatim in natural clear American English, as a warm adult podcast host teaching intermediate learners. Calm conversational delivery with meaningful phrasing. Maintain an even pace across segments. Do not add or omit words, music, introductions or sound effects.'}
  data=request('audio/speech',json.dumps(payload).encode(),'application/json');assert len(data)>1000;audio.write_bytes(data)
 if not timing.exists():
  response=transcribe(audio,text);words=response.get('words',[])
  if ''.join(normal(w['word']) for w in words)!=normal(text):
   (out/f'{n:02}-review.json').write_text(json.dumps(response,ensure_ascii=False,indent=2),encoding='utf-8');sys.exit(f'Segment {n}: transcription differs; audio retained for review, no estimated word times.')
  spans=[];cursor=0
  for w in words:
   size=len(normal(w['word']));spans.append((cursor,cursor+size,float(w['start']),float(w['end'])));cursor+=size
  cues=[];cursor=0
  for m in re.finditer(r"\w+(?:['’]\w+)*",text):
   size=len(normal(m.group()));matches=[s for s in spans if s[0]<cursor+size and s[1]>cursor];assert matches
   cues.append({'location':len(text[:m.start()].encode('utf-16-le'))//2,'length':len(m.group().encode('utf-16-le'))//2,'start':matches[0][2],'end':matches[-1][3]});cursor+=size
  timing.write_text(json.dumps({'text':text,'duration':response['duration'],'words':cues},ensure_ascii=False,indent=2),encoding='utf-8')
 probe=subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(audio)],capture_output=True,text=True,check=True)
 segment['duration']=float(json.loads(probe.stdout)['format']['duration'])
 assert max(w['end'] for w in json.loads(timing.read_text(encoding='utf-8'))['words'])<=segment['duration']+.25
 manifest.append({'number':n,'sha256':hashlib.sha256(audio.read_bytes()).hexdigest(),'text_sha256':hashlib.sha256(text.encode()).hexdigest()})
 print(f'Segment {n:02}: audio, measured word cues and media duration ready.',flush=True)
(out/'manifest.json').write_text(json.dumps({'episode':episode['id'],'voice':'marin','model':'gpt-4o-mini-tts','base_speed':episode['baseSpeed'],'ai_generated':True,'segments':manifest},indent=2)+'\n',encoding='utf-8')
path.write_text(json.dumps(episode,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'COMPLETE: {len(manifest)} segments; {sum(s["duration"] for s in episode["segments"])/60:.1f} minutes at slow speed; {sum(s["duration"] for s in episode["segments"])*episode["baseSpeed"]/60:.1f} minutes at normal speed.',flush=True)
