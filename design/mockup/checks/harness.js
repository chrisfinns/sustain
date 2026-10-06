const fs = require('fs');
const path = process.argv[2];
const html = fs.readFileSync(path, 'utf8');
const src = fs.readFileSync(__dirname + '/main.js', 'utf8').replace('class DCLogic { constructor(p){ this.props = p; } setState(){} forceUpdate(){} }',
  'class DCLogic { constructor(p){ this.props = p; } setState(p, cb){ const v = typeof p === "function" ? p(this.state) : p; this.state = Object.assign({}, this.state, v); if (cb) cb(); } forceUpdate(){} }');
const m = { exports: {} };
new Function('module', 'exports', src)(m, m.exports);
const Component = m.exports;
global.setTimeout = () => 0; global.clearTimeout = () => {}; global.setInterval = () => 0; global.clearInterval = () => {};
const tpl = html.slice(0, html.indexOf('<script type="text/x-dc"'));
const dotted = [...tpl.matchAll(/\{\{\s*([A-Za-z_$][\w$]*(?:\.[\w$]+)*)\s*\}\}/g)].map(x => x[1]);
const loops = [...tpl.matchAll(/<sc-for\s+list="\{\{\s*([\w.$]+)\s*\}\}"\s+as="(\w+)"/g)].map(x => ({ list: x[1], v: x[2] }));
const loopVars = new Set(loops.map(l => l.v));
const get = (o, p) => p.split('.').reduce((a, k) => (a == null ? undefined : a[k]), o);
let problems = 0;
function check(label, c) {
  const vals = c.renderVals();
  const missing = new Set();
  for (const d of dotted) {
    const head = d.split('.')[0];
    if (head === 'true' || head === 'false') continue;
    if (loopVars.has(head)) continue;
    if (get(vals, d) === undefined) missing.add(d);
  }
  // loop item fields
  const byVar = {};
  for (const l of loops) { (byVar[l.v] = byVar[l.v] || []).push(l.list); }
  for (const d of dotted) {
    const [head, ...rest] = d.split('.');
    if (!loopVars.has(head) || !rest.length) continue;
    const lists = byVar[head].map(L => loops.some(x => x.v === L.split('.')[0]) ? null : get(vals, L)).filter(Array.isArray);
    const nonEmpty = lists.filter(a => a.length);
    if (!nonEmpty.length) continue;
    const ok = nonEmpty.some(a => a.every(el => get(el, rest.join('.')) !== undefined));
    if (!ok) missing.add(d + ' (loop)');
  }
  if (missing.size) { problems++; console.log('[' + label + '] MISSING:', [...missing].join(', ')); }
  return vals;
}
const starts = ['today', 'practice', 'capture', 'capture-new', 'library', 'session', 'log', 'notes', 'settings'];
for (const st of starts) for (const pal of ['studio', 'console', 'circuit', 'paper']) for (const mode of ['system', 'dark', 'light']) {
  const c = new Component({ start: st, palette: pal, mode: mode }); check(`start=${st} ${pal}/${mode}`, c);
}
// appearance: overrides switch the live theme
{ const c = new Component({ start: 'settings' }); let v = c.renderVals();
  if (v.t.dir !== 'paper' || v.paletteCards[0].name !== 'Paper & Ink' || !v.paletteCards[0].on) { problems++; console.log('FAIL: Paper & Ink should be the default and first'); } else console.log('ok: Paper & Ink is the default and first card');
  if (v.paletteCards.length !== 4 || v.modeBtns.length !== 3) { problems++; console.log('FAIL: appearance controls'); }
  v.paletteCards.find(x => x.name === 'Circuit').pick(); v.modeBtns[2].pick(); v = c.renderVals();
  if (v.t.dir !== 'circuit' || v.t.mode !== 'light' || v.t.bg !== '#F2F2EF') { problems++; console.log('FAIL: override theme', v.t.dir, v.t.mode, v.t.bg); } else console.log('ok: appearance overrides switch theme');
  const hexOk = /^#[0-9A-F]{6}$/;
  const badTok = Object.entries(v.t).filter(([k, x]) => typeof x === 'string' && x.startsWith('#') && !hexOk.test(x));
  if (badTok.length) { problems++; console.log('FAIL: malformed tokens', badTok); } else console.log('ok: all tokens are valid hexes');
}

// ---- interaction scenarios
const assert = (cond, msg) => { if (!cond) { problems++; console.log('FAIL:', msg); } else console.log('ok:', msg); };
const key = (k, extra) => Object.assign({ key: k, preventDefault() {}, stopPropagation() { this.stopped = true; }, target: { tagName: 'INPUT' } }, extra || {});
let c = new Component({ start: 'today' });
let v = c.renderVals();
assert(v.warm.map(x => x.id).join() === 'spider,trills', 'warm-ups first by lane');
assert(v.warm[1].meta === 'Voice', 'no-area meta has no dangling separator: ' + v.warm[1].meta);
assert(v.warm[0].meta === 'Guitar · Technique', 'meta with area: ' + v.warm[0].meta);
assert(v.focus.map(x => x.id).join() === 'wing,para', 'focus lane');
assert(v.fresh.length === 3 && !v.fresh.some(x => x.lane === 'warmup'), 'new excludes warm-ups');
// capture: name only
v.openCapture(); v = c.renderVals();
assert(v.pk.chips.length === 6, 'six chips for guitar: ' + v.pk.chips.map(x => x.label).join('|'));
v.setName({ target: { value: 'Quick riff' } }); v = c.renderVals();
v.capKey(key('Enter')); v = c.renderVals();
const qr = c.state.items.find(i => i.title === 'Quick riff');
assert(qr && qr.areaId === null && qr.lane === 'normal', 'save with only a name');
assert(!c.state.capture, 'capture closed after Enter');
// capture: type Slap → Enter → pending chip; Enter again saves with new area
v.openCapture(); v = c.renderVals();
v.setName({ target: { value: 'Slap groove' } });
v.pickInst ? 0 : 0;
c.pickInst('bass'); v = c.renderVals();
v.pk.setText({ target: { value: 'Slap' } }); v = c.renderVals();
assert(v.pk.open && v.pk.rows.some(r => r.label === 'Create "Slap"' && r.on), 'Create "Slap" highlighted');
let e = key('Enter'); v.pk.onKey(e); v = c.renderVals();
assert(e.stopped, 'Enter with text does not bubble');
assert(c.state.capture && c.state.form.pendingArea === 'Slap', 'pending chip, not saved');
assert(v.pk.chips[0].label === 'Slap · new' && v.pk.chips[0].borderStyle === 'dashed', 'dashed new chip');
const nAreas = c.state.areas.length;
e = key('Enter'); v.pk.onKey(e); if (!e.stopped) v.capKey(e); v = c.renderVals();
const sg = c.state.items.find(i => i.title === 'Slap groove');
const slap = c.state.areas.find(a => a.name === 'Slap');
assert(sg && slap && sg.areaId === slap.id && c.state.areas.length === nAreas + 1, 'saved with new area Slap');
assert(/new area "Slap"/.test(c.state.toast), 'toast mentions new area: ' + c.state.toast);
// typo + warm-up row
v.openCapture(); v = c.renderVals();
v.pk.setText({ target: { value: 'Repertiore' } }); v = c.renderVals();
assert(v.pk.rows.find(r => r.on).label === 'Repertoire', 'typo highlights Repertoire');
v.pk.setText({ target: { value: 'warm up' } }); v = c.renderVals();
assert(v.pk.rows[0].label === 'Make this a daily warm-up' && v.pk.rows[0].on, 'warm-up row first');
v.pk.onKey(key('Enter')); v = c.renderVals();
assert(c.state.form.lane === 'warmup' && c.state.pk.text === '', 'warm row sets lane');
v.pk.setText({ target: { value: 'No area' } }); v = c.renderVals();
assert(v.pk.hasNote && !v.pk.rows.some(r => /Create/.test(r.label)), 'reserved name blocked');
// Esc twice creates nothing
v.pk.setText({ target: { value: 'Zzz' } }); v = c.renderVals();
e = key('Escape'); v.pk.onKey(e); if (!e.stopped) v.capKey(e); v = c.renderVals();
assert(c.state.capture && c.state.pk.text === '', 'first Esc clears text');
e = key('Escape'); v.pk.onKey(e); if (!e.stopped) v.capKey(e); v = c.renderVals();
assert(!c.state.capture && !c.state.areas.some(a => a.name === 'Zzz'), 'second Esc closes, no area created');
// Shift+Enter keeps inst/area/lane
v.openCapture(); c.pickInst('drums'); v = c.renderVals();
v.pk.chips.find(x => x.label === 'Rudiments').pick(); c.setForm({ lane: 'focus' }); v = c.renderVals();
v.setName({ target: { value: 'Flam taps' } }); v = c.renderVals();
v.capKey(key('Enter', { shiftKey: true })); v = c.renderVals();
assert(c.state.capture && c.state.form.inst === 'drums' && c.state.form.areaId === 'seed-rudiment' && c.state.form.lane === 'focus' && c.state.form.name === '', 'Shift+Enter keeps inst/area/lane');
v.closeCapture(); v = c.renderVals();
// instrument switch keeps area
v.openCapture(); v = c.renderVals();
v.pk.chips.find(x => x.label === 'Repertoire').pick(); c.pickInst('piano'); v = c.renderVals();
assert(c.state.form.areaId === 'seed-repertoire', 'instrument switch keeps area');
v.closeCapture(); v = c.renderVals();
// Settings: delete used area, undo
const beforeQ = JSON.stringify(c.computeQueue(c.state).ids);
const scale = v.areaRows.find(r => r.name === 'Scales');
scale.del(); v = c.renderVals();
assert(!c.state.areas.some(a => a.id === 'seed-scale') && c.state.items.find(i => i.id === 'penta').areaId === null, 'delete nulls items');
assert(JSON.stringify(c.computeQueue(c.state).ids) === beforeQ, 'Today unchanged by delete');
assert(c.state.toastUndo && /no area/.test(c.state.toast), 'undo toast: ' + c.state.toast);
v.undoArea(); v = c.renderVals();
assert(c.state.items.find(i => i.id === 'penta').areaId === 'seed-scale' && c.state.areas.some(a => a.id === 'seed-scale'), 'undo restores');
// rename collision -> merge
const lick = v.areaRows.find(r => r.name === 'Licks');
c.setItemArea('ivls', 'seed-lick');
v = c.renderVals();
const chords = v.areaRows.find(r => r.name === 'Chords');
chords.startEdit(); v = c.renderVals();
v.areaRows.find(r => r.editing).setEdit({ target: { value: 'lick' } }); v = c.renderVals();
v.areaRows.find(r => r.editing).editKey(key('Enter')); v = c.renderVals();
const ask = v.areaRows.find(r => r.isMergeAsk);
assert(ask && /Merge "Chords" into "Licks"\? 1 item moves/.test(ask.mergeText), 'merge prompt: ' + (ask && ask.mergeText));
ask.mergeYes(); v = c.renderVals();
assert(c.state.items.find(i => i.id === 'chart').areaId === 'seed-lick' && !c.state.areas.some(a => a.id === 'seed-chord'), 'merge moves items');
v.undoArea(); v = c.renderVals();
assert(c.state.items.find(i => i.id === 'chart').areaId === 'seed-chord' && c.state.items.find(i => i.id === 'ivls').areaId === 'seed-lick', 'merge undo restores only moved items');
// lane switch: reviewed warm-up -> Regular is due tomorrow
c.setLane('spider', 'normal'); v = c.renderVals();
const sp = c.state.items.find(i => i.id === 'spider');
assert(sp.kind === 'later' && sp.nextLabel === 'tomorrow' && !v.warm.some(x => x.id === 'spider'), 'reviewed warm-up -> regular due tomorrow');
c.setLane('walk', 'warmup'); v = c.renderVals();
assert(v.warm.some(x => x.id === 'walk') && !v.fresh.some(x => x.id === 'walk'), 'warm-up never in New');
// Library area filter + No area
c.setState({ screen: 'library', libStatus: 'all', libArea: 'none' }); v = c.renderVals();
assert(v.libRows.length > 0 && v.libRows.every(r => !r.areaId), 'No area filter');
c.setState({ libArea: 'seed-repertoire' }); v = c.renderVals();
v.openCapture(); v = c.renderVals();
assert(c.state.form.areaId === 'seed-repertoire', 'capture from Library preselects area filter');
v.closeCapture();
// Practice card picker
c = new Component({ start: 'practice' }); v = c.renderVals();
assert(v.cur.areaLabel === 'Repertoire', 'card shows area');
v.toggleCardPicker(); v = c.renderVals();
assert(v.cardPickerOpen && v.pk.chips.length > 0, 'card picker opens');
v.pk.setText({ target: { value: 'Solo study' } }); v = c.renderVals();
v.pk.onKey(key('Enter')); v = c.renderVals();
assert(c.item('wing').areaId && c.areaById(c.item('wing').areaId).name === 'Solo study' && !c.state.cardPicker, 'card creates + assigns area');
v.toggleCardPicker(); v = c.renderVals(); v.clearCardArea(); v = c.renderVals();
assert(c.item('wing').areaId === null && v.cur.areaLabel === '+ Area', 'card clears area');
// nameKey cases
const k = c.nameKey.bind(c);
const eq = [['Warm-Up', 'warm ups'], ['Techniques', 'Technique'], ['Range/Breath', 'Range & Breath'], ['B♭ voicings', 'Bb voicings']];
const ne = [['Bass', 'Bas'], ['C# major', 'C major']];
eq.forEach(([a, b]) => assert(k(a) === k(b), `nameKey ${a} == ${b}`));
ne.forEach(([a, b]) => assert(k(a) !== k(b), `nameKey ${a} != ${b}`));
// Notion preview
c = new Component({ start: 'settings' }); v = c.renderVals(); v.importNotion(); v = c.renderVals();
assert(v.showNotion && /9 match exactly · 1 same name, different spelling · 1 becomes the Warm-up setting · 0 new areas/.test(v.notionSummary), 'notion summary: ' + v.notionSummary);
console.log(problems ? problems + ' PROBLEM(S)' : 'ALL CHECKS PASSED');
// ---- regression checks for review fixes
c = new Component({ start: 'today' }); v = c.renderVals();
c.setLane('penta', 'warmup'); c.setLane('penta', 'normal'); v = c.renderVals();
const pe = c.item('penta');
assert(pe.kind === 'due' && pe.late === 5 && v.due.some(x => x.id === 'penta'), 'warm-up round trip with no rating restores schedule');
c.setLane('seven', 'warmup'); c.setLane('seven', 'normal');
assert(c.item('seven').kind === 'later' && c.item('seven').nextLabel === 'in 41d', 'round trip keeps far due date');
v = c.renderVals();
v.areaRows.find(r => r.name === 'Scales').del(); v = c.renderVals();
assert(c.toastMs === 10000, 'undo toast uses 10 s');
const jam = v.areaRows.find(r => r.name === 'Jam'); jam.startEdit(); v = c.renderVals();
v.areaRows.find(r => r.editing).setEdit({ target: { value: 'Scales' } }); v = c.renderVals();
v.areaRows.find(r => r.editing).editKey(key('Enter')); v = c.renderVals();
assert(c.state.undo === null, 'rename ends undo window');
c.setState({ undo: { type: 'delete', area: { id: 'seed-scale', name: 'Scales', nameKey: 'scale', color: '#fff', createdAt: 5 }, itemIds: ['penta'] } });
c.undoArea();
assert(c.state.areas.filter(a => a.nameKey === 'scale').length === 1, 'undo never duplicates a name');
v = c.renderVals(); v.openCapture(); v = c.renderVals();
v.pk.setText({ target: { value: 'Rep' } }); v = c.renderVals();
assert(v.pk.activeId === 'cap-area-sugg-0' && v.pk.rows[0].ring !== 'none', 'combobox active descendant + ring');
console.log(problems ? problems + ' PROBLEM(S)' : 'ALL CHECKS PASSED (incl. regressions)');
// ---- comment-round checks
{
  const tplText = tpl;
  assert(!/summaryLine/.test(tplText), 'Today summary line removed');
  assert(!/Metronome|toggleMetro|nudgeM5/.test(tplText), 'metronome removed from UI');
  assert(!/Played clean at|Best clean tempo|cap-bpm|it\.bpmCol|it\.bpmText/.test(tplText), 'tempo tracking removed from UI');
  let c = new Component({ start: 'practice' }); let v = c.renderVals();
  assert(/Thumb over the neck[\s\S]*Teacher/.test(v.cur.noteText), 'practice notes are one freeform text');
  v.setItemNote({ target: { value: 'New free text\nline two' } }); v = c.renderVals();
  assert(c.item('wing').noteText === 'New free text\nline two' && v.noteSaved === 'Saved', 'notes edit saves per item');
  c = new Component({ start: 'today' }); v = c.renderVals();
  v.openCapture(); v = c.renderVals();
  v.startInstCap(); v = c.renderVals();
  assert(v.instAddCap && !v.instAddCapBtn, 'add-instrument input opens in Capture');
  v.setInstDraft({ target: { value: 'Ukulele' } }); v = c.renderVals();
  let e = key('Enter'); v.instDraftKey(e); v = c.renderVals();
  assert(e.stopped && c.state.capture, 'Enter in instrument box does not save the item');
  assert(v.capInsts.some(x => x.name === 'Ukulele' && x.on) && v.instList.some(x => x.name === 'Ukulele'), 'new instrument selected and in sidebar');
  assert(v.pk.chips.length > 0, 'custom instrument gets area suggestions');
  v.startInstCap(); v = c.renderVals(); v.setInstDraft({ target: { value: 'guitar' } }); v.instDraftKey(key('Enter')); v = c.renderVals();
  assert(Object.keys(c.state.instruments).length === 6 && c.state.form.inst === 'guitar', 'duplicate instrument name selects existing');
  v.setName({ target: { value: 'Riptide chords' } });
  v.setCapNote({ target: { value: 'Capo 1. Strum D D U U D U.' } });
  v.addMockShot(); v.addMockShot(); v.addMockFile(); v = c.renderVals();
  assert(v.capAtts.length === 3 && v.capHasAtt, 'multiple attachments in Capture');
  v.capAtts[1].remove(); v = c.renderVals();
  assert(v.capAtts.length === 2, 'attachment removable');
  v.capKey(key('Enter')); v = c.renderVals();
  const rt = c.state.items.find(i => i.title === 'Riptide chords');
  assert(rt && rt.noteText === 'Capo 1. Strum D D U U D U.' && rt.media.images.length === 1 && rt.media.pdf === 'Tab-1.pdf', 'notes + attachments saved to item');
  c = new Component({ start: 'settings' }); v = c.renderVals();
  v.startInstSet(); v = c.renderVals(); v.setInstDraft({ target: { value: 'Cello' } }); v.instDraftBlur(); v = c.renderVals();
  assert(v.settingsInst.some(x => x.name === 'Cello'), 'add instrument from Settings');
  c = new Component({ start: 'capture-new' }); v = c.renderVals();
  assert(v.capAtts.length === 2 && v.laneHint.indexOf("before you'd forget") >= 0, 'capture-new shows screenshots + plain schedule copy');
}
console.log(problems ? problems + ' PROBLEM(S)' : 'ALL CHECKS PASSED (incl. comment round)');
