import { FocusSession } from '../models/FocusSession';

// 奖励原则：任何完整守住的正式专注都不能空手——5 分钟保底启动也有奖励。
// 时长只影响多少：短段按分钟计，30 分钟以上进入加速档，上限防刷。
export const TIME_COIN_MIN_FOCUS_SECONDS = 5 * 60;
export const TIME_COIN_ACCELERATE_SECONDS = 30 * 60;
export const TIME_COIN_BASE_REWARD = 30;
export const TIME_COIN_STEP_SECONDS = 5 * 60;
export const TIME_COIN_STEP_REWARD = 10;
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

  // 5-30 分钟：1 分钟 1 币，守住多少分钟就有多少币。
  if (durationSeconds < TIME_COIN_ACCELERATE_SECONDS) {
    return Math.floor(durationSeconds / 60);
  }

  // 30 分钟起 30 币，之后每满 5 分钟 +10，鼓励更长的完整专注。
  const extraSteps = Math.floor((durationSeconds - TIME_COIN_ACCELERATE_SECONDS) / TIME_COIN_STEP_SECONDS);
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
