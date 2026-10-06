const DAY_MS = 86_400_000;

/** Local calendar day as YYYY-MM-DD. */
export function dayKey(t: number | Date): string {
  const d = new Date(t);
  const m = d.getMonth() + 1;
  const day = d.getDate();
  return `${d.getFullYear()}-${m < 10 ? '0' : ''}${m}-${day < 10 ? '0' : ''}${day}`;
}

export function startOfDay(t: number | Date): number {
  const d = new Date(t);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

export function endOfDay(t: number | Date): number {
  return startOfDay(addDays(t, 1)) - 1;
}

/** Calendar-safe: adds days in local time, so DST shifts don't move the hour. */
export function addDays(t: number | Date, days: number): number {
  const d = new Date(t);
  d.setDate(d.getDate() + days);
  return d.getTime();
}

/** Whole local calendar days from a to b (b later is positive). */
export function daysBetween(a: number | Date, b: number | Date): number {
  return Math.round((startOfDay(b) - startOfDay(a)) / DAY_MS);
}

export function formatClock(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m < 10 ? '0' : ''}${m}:${r < 10 ? '0' : ''}${r}`;
}
