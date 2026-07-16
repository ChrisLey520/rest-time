import assert from 'node:assert/strict';
import { ABSENCE_THRESHOLD_DAYS, absenceDaysSinceLastSession, createStarterPlan } from './helpers/starterCore.mjs';

{
  const plan = createStarterPlan([], 25);

  assert.equal(plan.durationSeconds, 1500);
  assert.equal(plan.riskLevel, 'low');
  assert.equal(plan.reason, 'fresh_start');
}

{
  const sessions = [
    { status: 'abandoned', endedAt: 7000 },
    { status: 'completed', endedAt: 6000, countsAsFocus: true },
    { status: 'abandoned', endedAt: 5000 },
    { status: 'completed', endedAt: 4000, countsAsFocus: false, restartFromReason: 'abandoned_retry' }
  ];
  const plan = createStarterPlan(sessions, 25);

  assert.equal(plan.durationSeconds, 300);
  assert.equal(plan.riskLevel, 'high');
  assert.equal(plan.reason, 'recent_abandon');
}

{
  const sessions = [
    { status: 'completed', endedAt: 7000, countsAsFocus: true, awaySeconds: 60 },
    { status: 'completed', endedAt: 6000, countsAsFocus: true, returnProofRequiredCount: 1 },
    { status: 'completed', endedAt: 5000, countsAsFocus: true },
    { status: 'completed', endedAt: 4000, countsAsFocus: true }
  ];
  const plan = createStarterPlan(sessions, 25);

  assert.equal(plan.durationSeconds, 600);
  assert.equal(plan.riskLevel, 'medium');
  assert.equal(plan.reason, 'recent_away');
}

{
  const sessions = [
    { status: 'completed', endedAt: 7000, countsAsFocus: true },
    { status: 'completed', endedAt: 6000, countsAsFocus: true },
    { status: 'abandoned', endedAt: 5000 }
  ];
  const plan = createStarterPlan(sessions, 25);

  assert.equal(plan.durationSeconds, 900);
  assert.equal(plan.riskLevel, 'medium');
  assert.equal(plan.reason, 'low_completion');
}

// ---- 缺席回归 ----
{
  const now = Date.parse('2026-07-15T09:00:00');
  const oneDay = 24 * 60 * 60 * 1000;

  assert.equal(ABSENCE_THRESHOLD_DAYS, 2);
  assert.equal(absenceDaysSinceLastSession([], now), 0);
  assert.equal(absenceDaysSinceLastSession([{ endedAt: now - oneDay }], now), 1);
  assert.equal(absenceDaysSinceLastSession([{ endedAt: now - 3 * oneDay }], now), 3);

  // 缺席 3 天:即使历史记录良好,也走回归启动,5 分钟,不审判
  const goodHistory = [
    { status: 'completed', endedAt: now - 3 * oneDay, countsAsFocus: true },
    { status: 'completed', endedAt: now - 4 * oneDay, countsAsFocus: true },
    { status: 'completed', endedAt: now - 5 * oneDay, countsAsFocus: true }
  ];
  const absencePlan = createStarterPlan(goodHistory, 25, now);
  assert.equal(absencePlan.reason, 'long_absence');
  assert.equal(absencePlan.durationSeconds, 300);
  assert.equal(absencePlan.guardLabel, '欢迎回来');
  assert.equal(absencePlan.absenceDays, 3);

  // 昨天有记录:不触发回归,走正常判断
  const recentHistory = [
    { status: 'completed', endedAt: now - oneDay, countsAsFocus: true },
    { status: 'completed', endedAt: now - 2 * oneDay, countsAsFocus: true },
    { status: 'completed', endedAt: now - 3 * oneDay, countsAsFocus: true }
  ];
  const normalPlan = createStarterPlan(recentHistory, 25, now);
  assert.equal(normalPlan.reason, 'fresh_start');
  assert.equal(normalPlan.durationSeconds, 1500);

  // 不传 now(旧调用兼容):不触发回归判断
  const legacyPlan = createStarterPlan(goodHistory, 25);
  assert.equal(legacyPlan.reason, 'fresh_start');
}

console.log('starter core tests passed');
