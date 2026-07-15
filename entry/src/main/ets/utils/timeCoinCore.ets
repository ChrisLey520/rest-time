import { FocusSession } from '../models/FocusSession';

export const TIME_COIN_MIN_FOCUS_SECONDS = 30 * 60;
export const TIME_COIN_BASE_REWARD = 30;
export const TIME_COIN_STEP_SECONDS = 5 * 60;
export const TIME_COIN_STEP_REWARD = 5;
export const TIME_COIN_MAX_PER_SESSION = 120;
export const TIME_COIN_DAILY_CAP = 240;

function isSameLocalDay(timestamp: number, now: number): boolean {
  const date = new Date(timestamp);
  const current = new Date(now);
  return date.getFullYear() === current.getFullYear()
    && date.getMonth() === current.getMonth()
    && date.getDate() === current.getDate();
}

export function earnedTimeCoinsToday(sessions: FocusSession[], now: number): number {
  let total = 0;
  sessions.forEach((session: FocusSession) => {
    if (isSameLocalDay(session.endedAt, now)) {
      total += session.timeCoinsEarned ? session.timeCoinsEarned : 0;
    }
  });

  return Math.max(0, Math.floor(total));
}

export function potentialTimeCoinsForDuration(actualDurationSeconds: number): number {
  const durationSeconds = Math.max(0, Math.floor(actualDurationSeconds));
  if (durationSeconds < TIME_COIN_MIN_FOCUS_SECONDS) {
    return 0;
  }

  const extraSteps = Math.floor((durationSeconds - TIME_COIN_MIN_FOCUS_SECONDS) / TIME_COIN_STEP_SECONDS);
  const reward = TIME_COIN_BASE_REWARD + extraSteps * TIME_COIN_STEP_REWARD;
  return Math.min(TIME_COIN_MAX_PER_SESSION, reward);
}

export function awardTimeCoins(
  sessions: FocusSession[],
  actualDurationSeconds: number,
  now: number
): number {
  const remainingDailyCoins = Math.max(0, TIME_COIN_DAILY_CAP - earnedTimeCoinsToday(sessions, now));
  return Math.min(remainingDailyCoins, potentialTimeCoinsForDuration(actualDurationSeconds));
}
