// Dumps the mockup's Paper & Ink tokens (dark + light) so the Swift ThemeBuilder can be checked against them.
// Run from the repo root: node tools/theme-fixture/dump.cjs
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..', '..');
const html = fs.readFileSync(path.join(root, 'design/mockup/Main.dc.html'), 'utf8');
const m = html.match(/<script type="text\/x-dc" data-dc-script data-props='.*?'>([\s\S]*?)<\/script>/);
const src = 'class DCLogic { constructor(p){ this.props = p; } setState(){} forceUpdate(){} }\n' + m[1] + '\nmodule.exports = Component;\n';
const mod = { exports: {} };
new Function('module', 'exports', src)(mod, mod.exports);
const c = new mod.exports({});
const out = {};
for (const mode of ['dark', 'light']) {
  const T = c.buildTheme('paper', mode);
  const tokens = {};
  for (const [k, v] of Object.entries(T)) if (typeof v === 'string' && (v.startsWith('#') || v.startsWith('rgba'))) tokens[k] = v;
  out[mode] = { tokens, data: T.data };
}
const dest = path.join(root, 'Packages/SustainCore/Tests/SustainCoreTests/Fixtures/theme-paper.json');
fs.writeFileSync(dest, JSON.stringify(out, null, 1) + '\n');
console.log('wrote', dest, Object.keys(out.dark.tokens).length, 'tokens per mode');
