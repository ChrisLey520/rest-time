import assert from 'node:assert/strict';
import {
  TIME_COIN_DAILY_CAP,
  TIME_COIN_MAX_PER_SESSION,
  awardTimeCoins,
  earnedTimeCoinsToday,
  potentialTimeCoinsForDuration
} from './helpers/timeCoinCore.mjs';

const today = Date.parse('2026-06-25T08:00:00.000Z');
const yesterday = Date.parse('2026-06-24T08:00:00.000Z');

// 5 分钟以下无奖励(防秒刷)
assert.equal(potentialTimeCoinsForDuration(0), 0);
assert.equal(potentialTimeCoinsForDuration(4 * 60 + 59), 0);

// 5-30 分钟:1 分钟 1 币——保底启动和默认 25 分钟专注都不再空手
assert.equal(potentialTimeCoinsForDuration(5 * 60), 5);
assert.equal(potentialTimeCoinsForDuration(10 * 60), 10);
assert.equal(potentialTimeCoinsForDuration(25 * 60), 25);
assert.equal(potentialTimeCoinsForDuration(29 * 60 + 59), 29);

// 30 分钟起加速档:30 币起,每满 5 分钟 +10
assert.equal(potentialTimeCoinsForDuration(30 * 60), 30);
assert.equal(potentialTimeCoinsForDuration(45 * 60), 60);
assert.equal(potentialTimeCoinsForDuration(60 * 60), 90);

// 单次上限
assert.equal(potentialTimeCoinsForDuration(10 * 60 * 60), TIME_COIN_MAX_PER_SESSION);

// 奖励单调不减:更长的专注不会拿更少
assert.ok(potentialTimeCoinsForDuration(30 * 60) >= potentialTimeCoinsForDuration(29 * 60));

const sessions = [
  { endedAt: today, timeCoinsEarned: 120 },
  { endedAt: today + 60_000, timeCoinsEarned: 90 },
  { endedAt: yesterday, timeCoinsEarned: 120 }
];

assert.equal(earnedTimeCoinsToday(sessions, today), 210);
assert.equal(awardTimeCoins(sessions, 60 * 60, today), 30); // 日上限只剩 30
assert.equal(awardTimeCoins([{ endedAt: today, timeCoinsEarned: TIME_COIN_DAILY_CAP }], 60 * 60, today), 0);
assert.equal(awardTimeCoins([], 25 * 60, today), 25); // 默认专注完整守住有奖励

console.log('time coin core tests passed');
