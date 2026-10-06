import { COLOR_NAMES, type Area, type ColorName, type Item } from './types';

/** Case, punctuation and a trailing plural "s" fold together; musical symbols (#, b for flat) do not. */
export function nameKey(name: string): string {
  let k = String(name ?? '').normalize('NFKC').toLowerCase().replace(/♯/g, '#').replace(/♭/g, 'b');
  k = k.replace(/[\s\-–—_/&.,:;'"()!?]+/g, ' ').trim();
  if (!k) return '';
  const parts = k.split(' ');
  const last = parts[parts.length - 1];
  if (last.length >= 3 && /s$/.test(last) && !/ss$/.test(last)) parts[parts.length - 1] = last.slice(0, -1);
  return parts.join(' ');
}

export function cleanName(name: string, max = 32): string {
  return String(name ?? '').replace(/\s+/g, ' ').trim().slice(0, max);
}

export function isWarmupKey(key: string): boolean {
  return /\bwarm ?up\b/.test(key);
}

export function isReservedKey(key: string): boolean {
  return key === 'no area' || key === 'all area';
}

export type NameProblem = 'empty' | 'no-letters' | 'reserved' | null;

export function validateAreaName(name: string): NameProblem {
  if (!cleanName(name)) return 'empty';
  const key = nameKey(name);
  if (!key) return 'no-letters';
  if (isReservedKey(key)) return 'reserved';
  return null;
}

export const NAME_PROBLEM_TEXT: Record<Exclude<NameProblem, null>, string> = {
  empty: 'Type a name',
  'no-letters': 'Use a letter, number or emoji',
  reserved: 'That name is used by a filter',
};

export const SEED_AREA_NAMES = [
  'Repertoire', 'Technique', 'Ear Training', 'Transcription', 'Songwriting', 'Scales', 'Chords', 'Licks', 'Fretboard',
  'Jam', 'Grooves', 'Walking Lines', 'Voicings', 'Sight-Reading', 'Rudiments', 'Fills', 'Independence', 'Lyrics', 'Range & Breath',
];

export function slugOf(name: string): string {
  return nameKey(name).replace(/[^a-z0-9#]+/g, '-').replace(/^-+|-+$/g, '');
}

export function seedAreas(now: number): Area[] {
  return SEED_AREA_NAMES.map((name, i) => ({
    id: 'seed-' + slugOf(name),
    seedKey: slugOf(name),
    name,
    nameKey: nameKey(name),
    color: COLOR_NAMES[i % COLOR_NAMES.length],
    createdAt: now + i,
  }));
}

/** Day-one chip order per instrument. After that, usage outranks it. */
export const SEED_SUGGEST: Record<string, string[]> = {
  guitar: ['repertoire', 'chord', 'scale', 'lick', 'technique', 'ear-training'],
  bass: ['repertoire', 'groove', 'scale', 'walking-line', 'technique', 'ear-training'],
  piano: ['repertoire', 'voicing', 'scale', 'sight-reading', 'technique', 'ear-training'],
  drums: ['repertoire', 'rudiment', 'groove', 'fill', 'independence', 'technique'],
  voice: ['repertoire', 'range-breath', 'lyric', 'technique', 'ear-training', 'songwriting'],
  other: ['repertoire', 'technique', 'ear-training', 'transcription', 'songwriting'],
};

export function leastUsedColor(used: ColorName[]): ColorName {
  const counts = COLOR_NAMES.map((c) => used.filter((u) => u === c).length);
  return COLOR_NAMES[counts.indexOf(Math.min(...counts))];
}

export function pinFirst(ids: string[], id: string | null | undefined, max = 6): string[] {
  if (!id || ids.includes(id)) return ids;
  return [id, ...ids].slice(0, max);
}

/** Up to 6 chips for an instrument: most used there, then seed suggestions, then unused custom areas. */
export function rankAreasForCapture(areas: Area[], items: Pick<Item, 'areaId' | 'instrumentId'>[], instrumentId: string, selectedId: string | null): string[] {
  const here = new Map<string, number>();
  const anywhere = new Map<string, number>();
  for (const it of items) {
    if (!it.areaId) continue;
    anywhere.set(it.areaId, (anywhere.get(it.areaId) ?? 0) + 1);
    if (it.instrumentId === instrumentId) here.set(it.areaId, (here.get(it.areaId) ?? 0) + 1);
  }
  const used = areas
    .filter((a) => here.has(a.id))
    .sort((a, b) => here.get(b.id)! - here.get(a.id)! || a.createdAt - b.createdAt)
    .map((a) => a.id);
  const suggest = (SEED_SUGGEST[instrumentId] ?? SEED_SUGGEST.other)
    .map((k) => areas.find((a) => a.seedKey === k)?.id)
    .filter((x): x is string => !!x);
  const fresh = areas
    .filter((a) => !a.seedKey && !anywhere.has(a.id))
    .sort((a, b) => b.createdAt - a.createdAt)
    .map((a) => a.id);
  const out: string[] = [];
  for (const id of [...used, ...suggest, ...fresh]) if (!out.includes(id)) out.push(id);
  return pinFirst(out.slice(0, 6), selectedId);
}

/** Optimal string alignment distance (Damerau-Levenshtein with adjacent swaps). */
export function osa(a: string, b: string): number {
  const d: number[][] = [];
  for (let i = 0; i <= a.length; i++) d.push([i]);
  for (let j = 1; j <= b.length; j++) d[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
    }
  }
  return d[a.length][b.length];
}

function typoNear(q: string, key: string): boolean {
  if (key.length < 4 || q.length < 3) return false;
  return osa(q, key) <= (key.length >= 8 ? 2 : 1);
}

export type MatchRow =
  | { type: 'warmup'; label: string }
  | { type: 'area'; areaId: string; label: string; tier: 0 | 1 | 2 | 3 }
  | { type: 'create'; name: string; label: string };

export interface MatchResult {
  rows: MatchRow[];
  /** Index of the row Enter picks by default, or -1. */
  defaultIndex: number;
  problem: NameProblem;
}

/** Suggestions for typed text: warm-up row, matches (exact, prefix, substring, typo), then Create. */
export function matchAreas(query: string, areas: Area[]): MatchResult {
  const q = cleanName(query);
  if (!q) return { rows: [], defaultIndex: -1, problem: null };
  const key = nameKey(q);
  const rows: MatchRow[] = [];
  const warm = isWarmupKey(key);
  if (warm) rows.push({ type: 'warmup', label: 'Make this a daily warm-up' });
  const problem = validateAreaName(q);
  const scored = key
    ? areas
        .map((a) => {
          const k = a.nameKey;
          const tier = k === key ? 0 : k.startsWith(key) ? 1 : k.includes(key) ? 2 : typoNear(key, k) ? 3 : 9;
          return { a, tier };
        })
        .filter((x) => x.tier < 9)
        .sort((x, y) => x.tier - y.tier || x.a.name.localeCompare(y.a.name))
        .slice(0, 6)
    : [];
  for (const { a, tier } of scored) rows.push({ type: 'area', areaId: a.id, label: a.name, tier: tier as 0 | 1 | 2 | 3 });
  const exact = scored.some((x) => x.tier === 0);
  if (!exact && !problem) rows.push({ type: 'create', name: q, label: `Create "${q}"` });
  let defaultIndex = -1;
  if (warm) defaultIndex = 0;
  else {
    const strong = rows.findIndex((r) => r.type === 'area' && r.tier <= 1);
    const typo = rows.findIndex((r) => r.type === 'area' && r.tier === 3);
    const create = rows.findIndex((r) => r.type === 'create');
    defaultIndex = strong >= 0 ? strong : typo >= 0 ? typo : create;
  }
  return { rows, defaultIndex, problem: problem === 'empty' ? null : problem };
}
