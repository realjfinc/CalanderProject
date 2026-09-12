import json
from pathlib import Path

here = Path(__file__).resolve().parent
state = json.loads((here.parent / 'figma-progress.json').read_text(encoding='utf-8-sig'))
cases = []
for key, code in state['content'].items():
    code = code.replace("await figma.getNodeByIdAsync('8:154')", 'dateComponent')
    if key == 'appearance':
        code = code.replace("'Bright and clear','✓'", "'Bright and clear',theme==='Light'?'✓':'○'")
        code = code.replace("'Easy on the eyes','○'", "'Easy on the eyes',theme==='Dark'?'✓':'○'")
    if key == 'settings':
        code = code.replace("row(p,'Appearance','Light')", "row(p,'Appearance',theme)")
    cases.append('case '+json.dumps(key)+': {\n'+code+'\nbreak;\n}')
body = 'async function buildBody(key,p) { switch(key) {\n'+'\n'.join(cases)+'\ndefault: throw new Error("Missing screen: "+key);\n} }'
runtime = (here / 'runtime.js').read_text(encoding='utf-8')
code = 'const SCREENS = '+json.dumps(state['screens'],ensure_ascii=False)+';\n'+runtime.replace('// BODY_FUNCTIONS',body)
(here / 'code.js').write_text(code,encoding='utf-8')
assert len(state['screens']) == len(state['content']) == 46
print('Built local plugin for 46 screens in each theme (92 total).')
