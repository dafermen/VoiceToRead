from pathlib import Path
import json,urllib.request,urllib.error,sys
import argparse,re
parser=argparse.ArgumentParser();parser.add_argument('--lesson',default='SPK-B1-001');args=parser.parse_args()
if not re.fullmatch(r'SPK-(B1|B2|C1|C2)-[0-9]{3}',args.lesson):sys.exit('Invalid lesson identifier.')
r=Path(__file__).resolve().parents[1];folder=r/'VoiceToRead/Resources/SpeakingLessons'
d=json.loads((folder/(args.lesson+'.json')).read_text(encoding='utf-8'))
strings={}
def collect(value,path=''):
 if isinstance(value,dict):
  for k,v in value.items():collect(v,f'{path}.{k}' if path else k)
 elif isinstance(value,list):
  for i,v in enumerate(value):collect(v,f'{path}.{i}')
 elif isinstance(value,str) and (path.endswith(('.es','_es')) or path.startswith('learning_objectives.') or path.startswith('lesson_card.activities_es.') or path=='lesson_card.language'):
  strings[path]=value
collect(d)
key=next((x.partition('=')[2].strip().strip('"').strip("'") for x in (r/'.env').read_text(encoding='utf-8-sig').splitlines() if x.partition('=')[0].strip()=='OPENAI_API_KEY'),None)
if not key:sys.exit('Missing local key.')
for locale,language in [('fr','French'),('ko','Korean'),('ja','Japanese'),('zh-Hans','Simplified Chinese')]:
 path=folder/f'{args.lesson}-support-{locale}.json'
 if path.exists():print(locale+': existing support pack retained.',flush=True);continue
 schema={'type':'object','properties':{k:{'type':'string'} for k in strings},'required':list(strings),'additionalProperties':False}
 payload={'model':'gpt-4.1-mini','input':[{'role':'system','content':f'Translate the supplied Spanish educational support content accurately into {language} for an adult learning American English at {d["level"]} level. Preserve all facts, meaning, punctuation intent and grammatical terminology. When an English example or contraction is mentioned inside an explanation, retain it in English. Do not add activities, judgments, questions or explanations. Preserve all JSON keys. This is support text only; the English learning target remains English.'},{'role':'user','content':json.dumps(strings,ensure_ascii=False)}], 'text':{'format':{'type':'json_schema','name':'lesson_support','strict':True,'schema':schema}}}
 request=urllib.request.Request('https://api.openai.com/v1/responses',data=json.dumps(payload,ensure_ascii=False).encode(),headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'},method='POST')
 try:
  with urllib.request.urlopen(request,timeout=180) as response:result=json.load(response)
 except urllib.error.HTTPError as e:sys.exit('OpenAI HTTP '+str(e.code)+' (credentials not logged).')
 text=''.join(c.get('text','') for item in result.get('output',[]) for c in item.get('content',[]) if c.get('type')=='output_text')
 translated=json.loads(text)
 assert set(translated)==set(strings) and all(isinstance(x,str) and x.strip() for x in translated.values())
 path.write_text(json.dumps({'lesson':args.lesson,'locale':locale,'machine_translated':True,'strings':translated},ensure_ascii=False,indent=2),encoding='utf-8')
 print(locale+': '+str(len(strings))+' support texts translated and validated.',flush=True)
