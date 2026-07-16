import assert from 'node:assert/strict';
import {
  createFreeProState,
  isProActive,
  normalizeProState,
  proBadgeText,
  proStatusText
} from './helpers/proCore.mjs';

const now = Date.parse('2026-07-15T10:00:00');
const oneDay = 24 * 60 * 60 * 1000;

// 免费态
const free = createFreeProState();
assert.equal(isProActive(free, now), false);
assert.equal(proBadgeText(free, now), '体验期');
assert.match(proStatusText(free, now), /体验期/);

// 未过期的月度订阅有效
const monthly = { plan: 'monthly', expiresAt: now + 10 * oneDay, source: 'iap', verifiedAt: now };
assert.equal(isProActive(monthly, now), true);
assert.equal(proBadgeText(monthly, now), 'Pro');
assert.match(proStatusText(monthly, now), /月度订阅/);
assert.match(proStatusText(monthly, now), /2026\/7\/25 到期/);

// 过期的订阅回到体验期
const expired = { plan: 'yearly', expiresAt: now - oneDay, source: 'iap', verifiedAt: now - oneDay };
assert.equal(isProActive(expired, now), false);
assert.match(proStatusText(expired, now), /体验期/);

// 到期时刻边界:恰好等于 now 视为过期
assert.equal(isProActive({ plan: 'monthly', expiresAt: now, source: 'iap', verifiedAt: now }, now), false);

// lifetime 忽略到期时间
const lifetime = { plan: 'lifetime', expiresAt: 0, source: 'promo', verifiedAt: now };
assert.equal(isProActive(lifetime, now), true);
assert.equal(proStatusText(lifetime, now), '已订阅 · 永久版');

// 年度订阅文案
const yearly = { plan: 'yearly', expiresAt: now + 300 * oneDay, source: 'iap', verifiedAt: now };
assert.match(proStatusText(yearly, now), /年度订阅/);

// normalize 兜底脏数据
assert.deepEqual(normalizeProState(undefined), createFreeProState());
assert.equal(normalizeProState({ plan: 'hacked', expiresAt: 999 }).plan, 'none');
assert.equal(normalizeProState({ plan: 'hacked', expiresAt: 999 }).expiresAt, 0);
assert.equal(normalizeProState({ plan: 'monthly', expiresAt: -5, source: 'unknown' }).source, 'none');
assert.equal(normalizeProState({ plan: 'monthly', expiresAt: 1.9 }).expiresAt, 1);

console.log('pro core tests passed');
