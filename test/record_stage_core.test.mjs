import assert from 'node:assert/strict';
import {
  RECORD_STAGE_BILLING_PROJECT_SESSIONS,
  RECORD_STAGE_STEADY_ACTIVE_DAYS,
  createRecordStageSnapshot
} from './helpers/recordStageCore.mjs';

const now = Date.parse('2026-06-25T20:00:00');
const DAY_MS = 24 * 60 * 60 * 1000;

function completedSession(daysAgo, projectName) {
  const endedAt = now - daysAgo * DAY_MS;
  return {
    id: `session-${daysAgo}-${projectName || 'none'}-${Math.floor(endedAt)}`,
    plannedDurationSeconds: 1500,
    actualDurationSeconds: 1500,
    startedAt: endedAt - 1500 * 1000,
    endedAt,
    status: 'completed',
    projectName
  };
}

// 无记录：empty 阶段，月报和账单都不展示
const emptySnapshot = createRecordStageSnapshot([], now);
assert.equal(emptySnapshot.stage, 'empty');
assert.equal(emptySnapshot.showMonthlyReport, false);
assert.equal(emptySnapshot.showBilling, false);
assert.ok(emptySnapshot.unlockHint.length > 0);

// 只有放弃记录：不算活跃，仍是 light 阶段
const abandonedOnly = createRecordStageSnapshot([
  {
    id: 'abandoned-1',
    plannedDurationSeconds: 1500,
    actualDurationSeconds: 300,
    startedAt: now - 3600_000,
    endedAt: now - 3000_000,
    status: 'abandoned'
  }
], now);
assert.equal(abandonedOnly.stage, 'light');
assert.equal(abandonedOnly.activeDayCount, 0);
assert.equal(abandonedOnly.showMonthlyReport, false);

// 少量记录：活跃天数不足，light 阶段并提示剩余天数
const lightSnapshot = createRecordStageSnapshot([
  completedSession(0),
  completedSession(0),
  completedSession(1)
], now);
assert.equal(lightSnapshot.stage, 'light');
assert.equal(lightSnapshot.activeDayCount, 2);
assert.equal(lightSnapshot.showMonthlyReport, false);
assert.equal(lightSnapshot.showBilling, false);
assert.ok(lightSnapshot.unlockHint.includes('1 天'));

// 恢复阶梯和不计入专注的记录不算活跃天数
const recoverySnapshot = createRecordStageSnapshot([
  completedSession(0),
  completedSession(1),
  Object.assign(completedSession(2), { restartFromReason: 'abandoned_retry' }),
  Object.assign(completedSession(3), { countsAsFocus: false })
], now);
assert.equal(recoverySnapshot.stage, 'light');
assert.equal(recoverySnapshot.activeDayCount, 2);

// 稳定记录但项目归属不足：显示月报、不显示账单
const steadySessions = [];
for (let day = 0; day < RECORD_STAGE_STEADY_ACTIVE_DAYS; day += 1) {
  steadySessions.push(completedSession(day));
}
const steadySnapshot = createRecordStageSnapshot(steadySessions, now);
assert.equal(steadySnapshot.stage, 'steady');
assert.equal(steadySnapshot.activeDayCount, RECORD_STAGE_STEADY_ACTIVE_DAYS);
assert.equal(steadySnapshot.showMonthlyReport, true);
assert.equal(steadySnapshot.showBilling, false);
assert.ok(steadySnapshot.unlockHint.includes('项目归属'));

// 稳定记录且项目归属足够：月报和账单都展示
const billingSessions = [];
for (let index = 0; index < RECORD_STAGE_BILLING_PROJECT_SESSIONS; index += 1) {
  billingSessions.push(completedSession(index, '客户 A'));
}
const billingSnapshot = createRecordStageSnapshot(billingSessions, now);
assert.equal(billingSnapshot.stage, 'steady');
assert.equal(billingSnapshot.projectSessionCount, RECORD_STAGE_BILLING_PROJECT_SESSIONS);
assert.equal(billingSnapshot.showMonthlyReport, true);
assert.equal(billingSnapshot.showBilling, true);
assert.equal(billingSnapshot.unlockHint, '');

// 空白项目名不算项目归属
const blankProjectSnapshot = createRecordStageSnapshot([
  completedSession(0, '   '),
  completedSession(1, '   '),
  completedSession(2, '   ')
], now);
assert.equal(blankProjectSnapshot.stage, 'steady');
assert.equal(blankProjectSnapshot.projectSessionCount, 0);
assert.equal(blankProjectSnapshot.showBilling, false);

// 超出 30 天窗口的记录不算活跃
const staleSnapshot = createRecordStageSnapshot([
  completedSession(40),
  completedSession(45),
  completedSession(50)
], now);
assert.equal(staleSnapshot.stage, 'light');
assert.equal(staleSnapshot.activeDayCount, 0);

console.log('record stage core tests passed');
