const fs = require('fs');
const src = fs.readFileSync(__dirname + '/main.js', 'utf8').replace('class DCLogic { constructor(p){ this.props = p; } setState(){} forceUpdate(){} }',
  'class DCLogic { constructor(p){ this.props = p; } setState(p, cb){ const v = typeof p === "function" ? p(this.state) : p; this.state = Object.assign({}, this.state, v); if (cb) cb(); } forceUpdate(){} }');
const m = { exports: {} }; new Function('module', 'exports', src)(m, m.exports);
const C = m.exports;
const lum = h => { const [r, g, b] = [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16) / 255).map(c => c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
const cr = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
const c = new C({});
let fails = 0;
const report = [];
for (const dir of ['studio', 'console', 'circuit', 'paper']) for (const mode of ['dark', 'light']) {
  const T = c.buildTheme(dir, mode);
  const checks = [];
  const need = (fg, bgs, min, label) => bgs.forEach(b => checks.push([label || fg, fg, b, cr(T[fg] || fg, T[b] || b), min]));
  need('text', ['bg'], 7); need('text', ['surf', 'surf2', 'surf3', 'raised2', 'sel3', 'side'], 4.5);
  need('textSoft', ['surf'], 7);
  need('muted', ['bg', 'dim', 'side', 'surf', 'surf2', 'surf3', 'raised', 'raised2', 'sel', 'sel2', 'sel3', 'accentTint'], 4.5);
  need('faint', ['bg', 'dim', 'side', 'surf', 'surf2', 'surf3', 'raised2'], 4.5);
  need('onAccent', ['accent'], 4.5); need('onAccentLine', ['accent'], 1.5, 'kbd border on accent (decor)');
  need('accent', ['bg', 'surf', 'surf2', 'accentTint', 'accentTint2', 'sel3'], 4.5);
  need('again', ['surf', 'surf2', 'raised', 'againTint', 'againTint2'], 4.5);
  need('hard', ['surf', 'surf2', 'raised'], 4.5);
  need('good', ['surf', 'surf2', 'raised', 'goodTint'], 4.5);
  need('easy', ['surf', 'surf2', 'raised', 'easyTint'], 4.5);
  need('violet', ['violetTint', 'surf2'], 4.5);
  need('bg', ['text'], 7, 'toast');
  need('vidText', ['vid'], 4.5); need('paperMuted', ['paper'], 4.5); need('paperInk', ['paper'], 7);
  Object.entries(T.data).forEach(([k, v]) => { checks.push(['data:' + k, v, 'surf2', cr(v, T.surf2), 3]); checks.push(['data:' + k, v, 'bg', cr(v, T.bg), 3]); });
  need('line3', ['surf'], 1.25, 'card/row borders visible');
  const bad = checks.filter(x => x[3] < x[4]);
  fails += bad.length;
  report.push(`${dir}/${mode}: ${checks.length - bad.length}/${checks.length} pass` + (bad.length ? '\n   ' + bad.map(x => `${x[0]} on ${x[2]} = ${x[3].toFixed(2)} (< ${x[4]})`).join('\n   ') : ''));
}
console.log(report.join('\n'));
console.log(fails ? fails + ' CONTRAST FAILURES' : 'CONTRAST GATE PASSED');
