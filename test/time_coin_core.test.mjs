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

assert.equal(potentialTimeCoinsForDuration(29 * 60 + 59), 0);
assert.equal(potentialTimeCoinsForDuration(30 * 60), 30);
assert.equal(potentialTimeCoinsForDuration(45 * 60), 45);
assert.equal(potentialTimeCoinsForDuration(10 * 60 * 60), TIME_COIN_MAX_PER_SESSION);

const sessions = [
  { endedAt: today, timeCoinsEarned: 120 },
  { endedAt: today + 60_000, timeCoinsEarned: 90 },
  { endedAt: yesterday, timeCoinsEarned: 120 }
];

assert.equal(earnedTimeCoinsToday(sessions, today), 210);
assert.equal(awardTimeCoins(sessions, 60 * 60, today), 30);
assert.equal(awardTimeCoins([{ endedAt: today, timeCoinsEarned: TIME_COIN_DAILY_CAP }], 60 * 60, today), 0);

console.log('time coin core tests passed');
