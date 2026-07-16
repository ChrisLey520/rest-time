import assert from 'node:assert/strict';
import {
  STREAK_GUARD_MAX_HELD,
  STREAK_GUARD_PRICE,
  buyStreakGuard,
  createEmptyWallet,
  guardedStreakDays,
  normalizeWallet,
  timeCoinBalance,
  totalEarnedTimeCoins,
  totalSpentTimeCoins
} from './helpers/streakGuardCore.mjs';

const now = Date.parse('2026-07-15T10:00:00');

// ---- 余额 ----
const sessions = [
  { timeCoinsEarned: 100 },
  { timeCoinsEarned: 50 },
  { timeCoinsEarned: 0 },
  {}
];
assert.equal(totalEarnedTimeCoins(sessions), 150);
assert.equal(totalEarnedTimeCoins([]), 0);

const wallet = createEmptyWallet();
assert.equal(totalSpentTimeCoins(wallet), 0);
assert.equal(timeCoinBalance(sessions, wallet), 150);

// ---- 兑换 ----
// 余额足够:成功,扣 120,持券 +1
const buy1 = buyStreakGuard(sessions, wallet, now);
assert.equal(buy1.ok, true);
assert.equal(buy1.wallet.heldGuards, 1);
assert.equal(timeCoinBalance(sessions, buy1.wallet), 30);
assert.equal(buy1.wallet.spends[0].kind, 'streak_guard');
assert.equal(buy1.wallet.spends[0].amount, STREAK_GUARD_PRICE);

// 原钱包不被修改
assert.equal(wallet.heldGuards, 0);
assert.equal(wallet.spends.length, 0);

// 余额不足:失败并提示差额
const buy2 = buyStreakGuard(sessions, buy1.wallet, now + 1000);
assert.equal(buy2.ok, false);
assert.match(buy2.message, /还差 90 枚/);

// 持券上限
const richSessions = [{ timeCoinsEarned: 1000 }];
let richWallet = createEmptyWallet();
richWallet = buyStreakGuard(richSessions, richWallet, now).wallet;
richWallet = buyStreakGuard(richSessions, richWallet, now + 1).wallet;
assert.equal(richWallet.heldGuards, STREAK_GUARD_MAX_HELD);
const buyOver = buyStreakGuard(richSessions, richWallet, now + 2);
assert.equal(buyOver.ok, false);
assert.match(buyOver.message, /最多持有/);

// ---- 节奏计算 ----
// 无空白:全 focus
assert.deepEqual(
  guardedStreakDays(['focus', 'focus', 'focus'], 0),
  { streakDays: 3, guardsConsumed: 0, coveredIndexes: [] }
);

// 今天空白不算断
assert.equal(guardedStreakDays(['blank', 'focus', 'focus'], 0).streakDays, 2);

// 免费休息日先用:1 个空白日不消耗券
const freeRest = guardedStreakDays(['focus', 'blank', 'focus', 'focus'], 2);
assert.equal(freeRest.streakDays, 3);
assert.equal(freeRest.guardsConsumed, 0);

// 免费日用完后第 2 个空白消耗保护券
const useGuard = guardedStreakDays(['focus', 'blank', 'focus', 'blank', 'focus'], 1);
assert.equal(useGuard.streakDays, 3);
assert.equal(useGuard.guardsConsumed, 1);
assert.deepEqual(useGuard.coveredIndexes, [3]);

// 没券且免费日用完:节奏中断
const broken = guardedStreakDays(['focus', 'blank', 'focus', 'blank', 'focus'], 0);
assert.equal(broken.streakDays, 2);
assert.equal(broken.guardsConsumed, 0);

// covered 日不重复扣券
const covered = guardedStreakDays(['focus', 'blank', 'focus', 'covered', 'focus'], 0);
assert.equal(covered.streakDays, 3);
assert.equal(covered.guardsConsumed, 0);

// 两张券连续救 2 个空白
const twoGuards = guardedStreakDays(['focus', 'blank', 'blank', 'blank', 'focus'], 2);
assert.equal(twoGuards.streakDays, 2);
assert.equal(twoGuards.guardsConsumed, 2);
assert.deepEqual(twoGuards.coveredIndexes, [2, 3]);

// normalizeWallet 兜底旧数据
assert.deepEqual(normalizeWallet(undefined), { heldGuards: 0, coveredDayStarts: [], spends: [] });
assert.equal(normalizeWallet({ heldGuards: 1.9 }).heldGuards, 1);

console.log('streak guard core tests passed');
