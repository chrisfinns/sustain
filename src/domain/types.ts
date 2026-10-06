export type Lane = 'normal' | 'focus' | 'warmup';
export type RatingName = 'again' | 'hard' | 'good' | 'easy';
export type ColorName = 'amber' | 'coral' | 'rose' | 'violet' | 'blue' | 'teal' | 'green' | 'slate';

export const COLOR_NAMES: ColorName[] = ['amber', 'coral', 'rose', 'violet', 'blue', 'teal', 'green', 'slate'];

/** FSRS card as stored in IndexedDB: dates are epoch milliseconds so they can be indexed. */
export interface StoredCard {
  due: number;
  stability: number;
  difficulty: number;
  elapsed_days: number;
  scheduled_days: number;
  learning_steps: number;
  reps: number;
  lapses: number;
  /** ts-fsrs State: 0 New, 1 Learning, 2 Review, 3 Relearning */
  state: number;
  last_review: number | null;
}

export interface Instrument {
  id: string;
  name: string;
  color: ColorName;
  order: number;
  createdAt: number;
}

export interface Area {
  id: string;
  name: string;
  nameKey: string;
  color: ColorName;
  seedKey?: string;
  createdAt: number;
}

export interface YouTubeRef {
  url: string;
  videoId: string;
  /** Loop points in seconds; null when not set. */
  loopA: number | null;
  loopB: number | null;
  loopOn: boolean;
  /** Playback rate, e.g. 0.75 */
  speed: number;
}

export interface Item {
  id: string;
  title: string;
  instrumentId: string;
  areaId: string | null;
  lane: Lane;
  /** When the item last entered the warm-up lane (ms), used when it leaves. */
  warmupSince: number | null;
  paused: boolean;
  reference: boolean;
  artist: string;
  /** Freeform notes. */
  notes: string;
  youtube: YouTubeRef | null;
  /** Other links pasted at capture. */
  links: string[];
  card: StoredCard;
  createdAt: number;
  updatedAt: number;
}

export type AttachmentKind = 'image' | 'pdf' | 'audio' | 'file';

export interface Attachment {
  id: string;
  itemId: string;
  kind: AttachmentKind;
  name: string;
  mime: string;
  size: number;
  blob: Blob;
  createdAt: number;
}

export interface Review {
  id: string;
  itemId: string;
  rating: RatingName;
  /** Epoch ms of the rating. */
  at: number;
  /** Local calendar day of the rating, YYYY-MM-DD. */
  day: string;
  prevCard: StoredCard;
  nextCard: StoredCard;
}

export type PaletteName = 'paper' | 'studio' | 'console' | 'circuit';
export type ModeSetting = 'system' | 'dark' | 'light';

export interface Settings {
  retention: number;
  maxInterval: number;
  newPerDay: number;
  simple: boolean;
  palette: PaletteName;
  mode: ModeSetting;
}

export const DEFAULT_SETTINGS: Settings = {
  retention: 0.9,
  maxInterval: 60,
  newPerDay: 3,
  simple: false,
  palette: 'paper',
  mode: 'system',
};
