import re, sys, json, subprocess
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
m = re.search(r'<script type="text/x-dc" data-dc-script data-props=\'(.*?)\'>(.*?)</script>', s, re.S)
props, js = m.group(1), m.group(2)
json.loads(props.replace('&amp;', '&').replace('&#39;', "'"))
open(sys.argv[2], 'w').write('class DCLogic { constructor(p){ this.props = p; } setState(){} forceUpdate(){} }\n' + js + '\nmodule.exports = Component;\n')
r = subprocess.run(['node', '--check', sys.argv[2]], capture_output=True, text=True)
print('node --check:', 'OK' if r.returncode == 0 else r.stderr)
tpl = s[:m.start()]
names = set(re.findall(r'\{\{\s*([A-Za-z_$][\w$]*)', tpl))
loopvars = set(re.findall(r'<sc-for[^>]*\bas="(\w+)"', tpl))
top = names - loopvars - {'true', 'false'}
print('top-level template names:', len(top))
open(sys.argv[2] + '.names.json', 'w').write(json.dumps(sorted(top)))
# unbalanced sc-if / sc-for
for tag in ['sc-if', 'sc-for', 'div', 'button', 'section', 'span']:
    o = len(re.findall(r'<%s[\s>]' % tag, tpl)); c = len(re.findall(r'</%s>' % tag, tpl))
    if o != c: print('UNBALANCED', tag, o, c)
