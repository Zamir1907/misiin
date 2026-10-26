from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
html=list(root.glob('*.html'))
errors=[]
for f in html:
 s=f.read_text(encoding='utf-8')
 if 'name="viewport"' not in s: errors.append(f'{f.name}: viewport missing')
 if '/assets/css/responsive-fixes.css' not in s: errors.append(f'{f.name}: responsive CSS missing')
 for href in re.findall(r'<link[^>]+href="(/assets/[^"?#]+)',s):
  if not (root/href.lstrip('/')).is_file(): errors.append(f'{f.name}: missing {href}')
css=(root/'assets/css/responsive-fixes.css').read_text()
for breakpoint in ('320px','375px','767px','1024px'):
 if breakpoint not in css: errors.append(f'missing breakpoint {breakpoint}')
print(f'Checked {len(html)} HTML pages; errors: {len(errors)}')
for e in errors:print('ERROR:',e)
sys.exit(bool(errors))
