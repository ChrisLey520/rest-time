import assert from 'node:assert/strict';
import { FOCUS_EFFECTS, findFocusEffect, isEffectUnlocked, unlockFocusEffect } from './helpers/focusEffectCore.mjs';
import { unlockFocusTheme } from './helpers/focusThemeCore.mjs';
import { createEmptyWallet, timeCoinBalance } from './helpers/streakGuardCore.mjs';

const now = Date.parse('2026-07-15T10:00:00');

// 动效定义:6 个,默认免费,圆环层数 1-4
assert.equal(FOCUS_EFFECTS.length, 6);
assert.deepEqual(FOCUS_EFFECTS.map((effect) => effect.price), [0, 250, 350, 300, 400, 550]);
assert.deepEqual(FOCUS_EFFECTS.map((effect) => effect.ringColors.length), [1, 2, 3, 2, 3, 4]);

// id 唯一
assert.equal(new Set(FOCUS_EFFECTS.map((effect) => effect.id)).size, FOCUS_EFFECTS.length);

// 未知 id 回退默认
assert.equal(findFocusEffect('stardust').title, '星尘');
assert.equal(findFocusEffect('missing').id, 'ripple');

// 默认动效始终解锁
const wallet = createEmptyWallet();
assert.equal(isEffectUnlocked('ripple', wallet), true);
assert.equal(isEffectUnlocked('stardust', wallet), false);

// 余额不足
const poorSessions = [{ timeCoinsEarned: 100 }];
const failBuy = unlockFocusEffect('stardust', poorSessions, wallet, now);
assert.equal(failBuy.ok, false);
assert.match(failBuy.message, /还差 150 枚/);

// 解锁成功且不可变
const richSessions = [{ timeCoinsEarned: 700 }];
const okBuy = unlockFocusEffect('stardust', richSessions, wallet, now);
assert.equal(okBuy.ok, true);
assert.equal(okBuy.wallet.spends[0].kind, 'effect_stardust');
assert.equal(timeCoinBalance(richSessions, okBuy.wallet), 450);
assert.equal(wallet.spends.length, 0);
assert.equal(isEffectUnlocked('stardust', okBuy.wallet), true);

// 重复解锁被拒
assert.equal(unlockFocusEffect('stardust', richSessions, okBuy.wallet, now + 1).ok, false);

// 免费动效不可购买
assert.equal(unlockFocusEffect('ripple', richSessions, wallet, now).ok, false);

// 动效/主题/保护券共享同一钱包:动效消费后主题解锁按剩余余额判断
const afterEffect = okBuy.wallet; // 余额 450
const themeBuy = unlockFocusTheme('forest', richSessions, afterEffect, now + 2); // 400 币
assert.equal(themeBuy.ok, true);
assert.equal(timeCoinBalance(richSessions, themeBuy.wallet), 50);
const secondEffect = unlockFocusEffect('aurora', richSessions, themeBuy.wallet, now + 3); // 350 币
assert.equal(secondEffect.ok, false);
assert.match(secondEffect.message, /还差 300 枚/);

// 主题解锁不影响动效解锁状态,反之亦然
assert.equal(isEffectUnlocked('stardust', themeBuy.wallet), true);
assert.equal(isEffectUnlocked('aurora', themeBuy.wallet), false);

console.log('focus effect core tests passed');
