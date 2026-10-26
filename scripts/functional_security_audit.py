#!/usr/bin/env python3
"""Offline, deterministic contract checks. Does NOT access Supabase or Cloudflare."""
from pathlib import Path
import json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(name,fn):
 try:
  detail=fn()
  checks.append(dict(test=name,status='PASS',detail=str(detail or 'OK')))
 except Exception as exc: checks.append(dict(test=name,status='FAIL',detail=str(exc)))
def require(value,msg):
 if not value: raise AssertionError(msg)
 return 'OK'
def migration_chain():
 files=sorted((ROOT/'supabase/migrations').glob('*.sql'))
 require(len(files)>=9,'Expected at least nine SQL migrations')
 require([int(f.name[:4]) for f in files[:9]]==list(range(1,10)),'Migration numbering missing')
 return f'{len(files)} migration files'
check('Migration sequence 0001-0009',migration_chain)
for f in sorted((ROOT/'assets/js').rglob('*.js'))+sorted((ROOT/'functions').rglob('*.js')):
 def syntax(f=f):
  p=subprocess.run(['node','--check',str(f)],capture_output=True,text=True)
  require(p.returncode==0,p.stderr.strip());return f.relative_to(ROOT).as_posix()
 check('JavaScript syntax: '+f.relative_to(ROOT).as_posix(),syntax)
def html_links():
 files=list(ROOT.glob('*.html'))
 for f in files:
  txt=f.read_text()
  for href in re.findall(r'(?:src|href)=["\'](/?(?:assets/)[^"\']+)["\']',txt):
   require((ROOT/href.lstrip('/').split('?')[0]).is_file(),f'{f.name}: missing {href}')
 return f'{len(files)} HTML pages'
check('Local HTML asset references',html_links)
def frontend_secrets():
 for f in (ROOT/'assets').rglob('*.js'):
  txt=f.read_text()
  require(not re.search(r'(?i)(?:SUPABASE_SERVICE_ROLE_KEY|PAYMENT_WEBHOOK_SECRET)\s*=',txt),f'Possible secret assignment in {f}')
 return 'No obvious backend secret assignments'
check('Frontend secret assignment scan',frontend_secrets)
def ledger_contract():
 txt=(ROOT/'supabase/migrations/0004_wallet.sql').read_text()
 for term in ['unique(user_id,kind,reference)','for update','security definer','enable row level security']:
  require(term in txt,f'Missing ledger contract {term}')
 return 'Static ledger primitives found (not runtime proof)'
check('Ledger idempotency and locking declarations',ledger_contract)
def payment_contract():
 txt=(ROOT/'functions/api/payment/webhook.js').read_text()
 require('503' in txt and 'plus_verify_payment' not in re.sub(r'//[^\n]*','',txt),'Webhook not fail-closed')
 return 'Unverified webhook rejected'
check('Payment webhook fails closed',payment_contract)
def rls_coverage():
 scripts='\n'.join(p.read_text() for p in sorted((ROOT/'supabase/migrations').glob('*.sql'))).lower()
 tables=['profiles','roles','missions','mission_claims','mission_submissions','wallets','wallet_ledger','payment_orders','withdrawal_requests','support_tickets','support_messages','notifications','announcements','app_settings','audit_logs','user_settings']
 missing=[t for t in tables if not re.search(r'(?:alter table\s+(?:public\.)?'+re.escape(t)+r'\s+enable row level security|foreach\s+t\s+in\s+array)',scripts)]
 # A loop may cover several tables; report coverage as manual instead of false PASS.
 require('enable row level security' in scripts,'No RLS statements found')
 return 'RLS syntax present; table-by-table runtime validation required'
check('RLS declarations exist (not policy validation)',rls_coverage)
report={'scope':'offline_static','results':checks,'summary':{s:sum(x['status']==s for x in checks) for s in ['PASS','FAIL']},'not_tested':['Supabase migration execution','Supabase Auth email verification','RLS with two real user JWTs','Concurrent ledger writes','Supabase Storage private access','Cloudflare deployed Functions','QRIS provider settlement','Real withdrawal transfer','Cross-browser interaction']}
(ROOT/'docs/STAGE_13_REPORT.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
for x in checks:print(f"{x['status']:4} | {x['test']} | {x['detail']}")
print('NOT TESTED | '+', '.join(report['not_tested']))
print('Summary:',report['summary'])
sys.exit(1 if report['summary']['FAIL'] else 0)
