import json,glob,importlib,sys,re
sys.path.insert(0,'.')
P='../../assets/content/learn.json'
d=json.load(open(P))
B={}
for f in sorted(glob.glob('b*.py')):
    if f in('build.py','b99_try.py'):continue
    B.update(importlib.import_module(f[:-3]).L)
def words(l):
    b=l['body'];t=[b['intro']]+[h+' '+p for h,p in b['sections']]+[b['example']['title'],b['example']['text']]+b['takeaways']+b['reflect']+[l['tryThis']]
    return len(re.findall(r"\S+",' '.join(t)))
from b99_try import T
tot=0
for l in d['lessons']:
    if l['id'] in B:
        x=B[l['id']];l['body']=dict(intro=x['intro'],sections=[[h,p] for h,p in x['sections']],example=dict(title=x['example'][0],text=x['example'][1]),takeaways=x['takeaways'],reflect=x['reflect'])
        l['tryThis']=T[l['id']]
    if 'body' in l:
        w=words(l);tot+=w;print(l['id'],w)
print('missing',[l['id'] for l in d['lessons'] if 'body' not in l]);print('total',tot)
d['version']=2
if '--write' in sys.argv: json.dump(d,open(P,'w'),ensure_ascii=False,indent=1)
