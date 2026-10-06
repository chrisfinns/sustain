// Golden cases for the Swift FSRS port: the raw ts-fsrs engine with Sustain's settings
// (long-term scheduler, no fuzz). Deterministic: same seed, same file.
// Run: npm ci && npm run gen
import { writeFileSync } from 'node:fs';
import { createEmptyCard, fsrs, generatorParameters } from 'ts-fsrs';

const OUT = new URL('../../Packages/SustainCore/Tests/SustainCoreTests/Fixtures/fsrs-cases.json', import.meta.url);
const DAY = 86_400_000;

function mulberry32(seed) {
  return () => {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rnd = mulberry32(20261006);
const int = (lo, hi) => lo + Math.floor(rnd() * (hi - lo + 1));
const pick = (xs) => xs[Math.floor(rnd() * xs.length)];

const plain = (c) => ({
  due: c.due.getTime(),
  stability: c.stability,
  difficulty: c.difficulty,
  elapsed_days: c.elapsed_days,
  scheduled_days: c.scheduled_days,
  reps: c.reps,
  lapses: c.lapses,
  state: c.state,
  last_review: c.last_review ? c.last_review.getTime() : null,
});

const cases = [];
for (let n = 0; n < 200; n++) {
  const retention = pick([0.9, 0.9, 0.85, 0.95, 0.8, 0.97]);
  const maxInterval = pick([60, 60, 120, 30, 36500]);
  const f = fsrs(generatorParameters({ request_retention: retention, maximum_interval: maxInterval, enable_short_term: false, enable_fuzz: false }));
  const start = Date.UTC(2026, int(0, 11), int(1, 28), int(0, 23), int(0, 59));
  let card = createEmptyCard(new Date(start));
  const initial = plain(card);
  const steps = [];
  let now = start;
  for (let i = 0, len = int(1, 15); i < len; i++) {
    // Mostly on time, sometimes early or late, at a random hour.
    const offset = pick([0, 0, 0, -1, -2, 1, 2, 3, 5, 9, 14]);
    const base = i === 0 ? start : card.due.getTime() + offset * DAY;
    now = Math.max(now + int(1, 6) * 3_600_000, base + int(-8, 8) * 3_600_000);
    const rating = pick([1, 2, 3, 3, 3, 3, 4, 4]);
    card = f.next(card, new Date(now), rating).card;
    steps.push({ at: now, rating, card: plain(card) });
  }
  cases.push({ retention, maxInterval, initial, steps });
}
const header = '{"generator": "ts-fsrs 5.4.2, enable_short_term=false, enable_fuzz=false",\n"cases": [\n';
writeFileSync(OUT, header + cases.map((c) => JSON.stringify(c)).join(',\n') + '\n]}\n');
console.log('wrote', cases.length, 'cases,', cases.reduce((a, c) => a + c.steps.length, 0), 'steps');
