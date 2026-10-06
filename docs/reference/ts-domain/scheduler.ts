import { createEmptyCard, fsrs, generatorParameters, Rating, State, type Card, type Grade } from 'ts-fsrs';
import { addDays, daysBetween, startOfDay } from './dates';
import type { RatingName, StoredCard } from './types';

export const RATINGS: RatingName[] = ['again', 'hard', 'good', 'easy'];
export const SIMPLE_RATINGS: RatingName[] = ['again', 'good'];

export interface SchedulerOptions {
  retention: number;
  maxInterval: number;
}

const GRADE: Record<RatingName, Grade> = {
  again: Rating.Again,
  hard: Rating.Hard,
  good: Rating.Good,
  easy: Rating.Easy,
};

// Practice works in days: no Anki-style 1m/10m learning steps, no fuzz (predictable intervals).
function engine(opts: SchedulerOptions) {
  return fsrs(
    generatorParameters({
      request_retention: opts.retention,
      maximum_interval: opts.maxInterval,
      enable_short_term: false,
      enable_fuzz: false,
    }),
  );
}

export function toStored(c: Card): StoredCard {
  return {
    due: c.due.getTime(),
    stability: c.stability,
    difficulty: c.difficulty,
    elapsed_days: c.elapsed_days,
    scheduled_days: c.scheduled_days,
    learning_steps: c.learning_steps,
    reps: c.reps,
    lapses: c.lapses,
    state: c.state,
    last_review: c.last_review ? c.last_review.getTime() : null,
  };
}

export function fromStored(c: StoredCard): Card {
  return {
    due: new Date(c.due),
    stability: c.stability,
    difficulty: c.difficulty,
    elapsed_days: c.elapsed_days,
    scheduled_days: c.scheduled_days,
    learning_steps: c.learning_steps,
    reps: c.reps,
    lapses: c.lapses,
    state: c.state as State,
    last_review: c.last_review == null ? undefined : new Date(c.last_review),
  };
}

export function newCard(now: number): StoredCard {
  return toStored(createEmptyCard(new Date(now)));
}

export function isNew(c: StoredCard): boolean {
  return c.state === State.New;
}

/** Enforce the longest-gap cap ourselves: the engine can land a day past it. */
function capInterval(card: StoredCard, now: number, maxInterval: number): StoredCard {
  const days = daysBetween(now, card.due);
  if (days <= maxInterval) return card;
  return { ...card, scheduled_days: maxInterval, due: addDays(startOfDay(now), maxInterval) + (card.due - startOfDay(card.due)) };
}

export function rate(card: StoredCard, rating: RatingName, now: number, opts: SchedulerOptions): StoredCard {
  const rec = engine(opts).next(fromStored(card), new Date(now), GRADE[rating]);
  return capInterval(toStored(rec.card), now, opts.maxInterval);
}

/** Days until each rating would bring the item back (at least 1). */
export function preview(card: StoredCard, now: number, opts: SchedulerOptions): Record<RatingName, number> {
  const out = {} as Record<RatingName, number>;
  for (const r of RATINGS) {
    const next = rate(card, r, now, opts);
    out[r] = Math.max(1, daysBetween(now, next.due));
  }
  return out;
}

/** Compact interval label for the rating buttons: 1d, 9d, 3w, 2mo. */
export function intervalLabel(days: number): string {
  if (days < 14) return `${days}d`;
  if (days < 56) return `${Math.round(days / 7)}w`;
  return `${Math.round(days / 30)}mo`;
}

/** "tomorrow", "in 9d", "in 3w" for lists. */
export function nextLabel(days: number): string {
  if (days <= 0) return 'today';
  if (days === 1) return 'tomorrow';
  return `in ${intervalLabel(days)}`;
}

/** Plain-language stage shown in the Library. */
export function stageOf(card: StoredCard, maxInterval: number): 'New' | 'Learning' | 'Review' | 'Mastered' {
  if (card.state === State.New) return 'New';
  if (card.scheduled_days >= maxInterval) return 'Mastered';
  if (card.state === State.Learning || card.state === State.Relearning || card.scheduled_days < 7) return 'Learning';
  return 'Review';
}
