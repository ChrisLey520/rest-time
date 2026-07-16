import assert from 'node:assert/strict';
import { FOCUS_THEMES, findFocusTheme, isThemeUnlocked, unlockFocusTheme } from './helpers/focusThemeCore.mjs';
import { createEmptyWallet, timeCoinBalance } from './helpers/streakGuardCore.mjs';

const now = Date.parse('2026-07-15T10:00:00');

// 主题定义:12 个主题,默认免费,付费主题定价 300-1000
assert.equal(FOCUS_THEMES.length, 12);
assert.equal(FOCUS_THEMES[0].price, 0);
assert.deepEqual(
  FOCUS_THEMES.map((theme) => theme.price),
  [0, 300, 400, 500, 350, 450, 600, 800, 380, 520, 560, 1000]
);

// id 唯一
assert.equal(new Set(FOCUS_THEMES.map((theme) => theme.id)).size, FOCUS_THEMES.length);

// findFocusTheme:未知 id 回退默认
assert.equal(findFocusTheme('dusk').title, '暮色');
assert.equal(findFocusTheme('missing').id, 'default');

// 默认主题始终解锁
const wallet = createEmptyWallet();
assert.equal(isThemeUnlocked('default', wallet), true);
assert.equal(isThemeUnlocked('dusk', wallet), false);

// 余额不足:失败并提示差额
const poorSessions = [{ timeCoinsEarned: 100 }];
const failBuy = unlockFocusTheme('dusk', poorSessions, wallet, now);
assert.equal(failBuy.ok, false);
assert.match(failBuy.message, /还差 200 枚/);

// 余额足够:解锁成功,扣费,原钱包不变
const richSessions = [{ timeCoinsEarned: 800 }];
const okBuy = unlockFocusTheme('dusk', richSessions, wallet, now);
assert.equal(okBuy.ok, true);
assert.equal(okBuy.message, '已解锁「暮色」');
assert.equal(okBuy.wallet.spends[0].kind, 'theme_dusk');
assert.equal(timeCoinBalance(richSessions, okBuy.wallet), 500);
assert.equal(wallet.spends.length, 0);

// 解锁后 isThemeUnlocked 为 true;重复解锁被拒绝
assert.equal(isThemeUnlocked('dusk', okBuy.wallet), true);
const rebuy = unlockFocusTheme('dusk', richSessions, okBuy.wallet, now + 1000);
assert.equal(rebuy.ok, false);
assert.match(rebuy.message, /已经可用/);

// 解锁主题不影响保护券持有数
assert.equal(okBuy.wallet.heldGuards, wallet.heldGuards);

// 免费主题不可购买
const freeBuy = unlockFocusTheme('default', richSessions, wallet, now);
assert.equal(freeBuy.ok, false);

// 主题消费与保护券消费共享同一钱包余额
const mixedBalance = timeCoinBalance(richSessions, okBuy.wallet);
assert.equal(mixedBalance, 500);
const secondBuy = unlockFocusTheme('tide', richSessions, okBuy.wallet, now + 2000);
assert.equal(secondBuy.ok, true);
assert.equal(timeCoinBalance(richSessions, secondBuy.wallet), 0);

console.log('focus theme core tests passed');
