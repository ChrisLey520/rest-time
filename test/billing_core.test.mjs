import assert from 'node:assert/strict';
import {
  createBillingInsight,
  createBillingSuggestion,
  createBillingSummary
} from './helpers/billingCore.mjs';

const now = Date.parse('2026-06-24T12:00:00.000Z');
const settings = {
  hourlyRate: 240,
  minimumBillableMinutes: 15,
  roundingMinutes: 15,
  currencySymbol: '¥'
};

const sessions = [
  {
    id: 'session_1',
    taskTitle: '客户方案',
    projectName: '客户 A',
    status: 'completed',
    plannedDurationSeconds: 1500,
    actualDurationSeconds: 1500,
    startedAt: Date.parse('2026-06-02T02:00:00.000Z'),
    endedAt: Date.parse('2026-06-02T02:25:00.000Z')
  },
  {
    id: 'session_2',
    taskTitle: '短会议',
    projectName: '客户 A',
    status: 'completed',
    plannedDurationSeconds: 600,
    actualDurationSeconds: 600,
    startedAt: Date.parse('2026-06-03T03:00:00.000Z'),
    endedAt: Date.parse('2026-06-03T03:10:00.000Z')
  },
  {
    id: 'session_3',
    taskTitle: '交付复盘',
    projectName: '客户 B',
    status: 'completed',
    plannedDurationSeconds: 3600,
    actualDurationSeconds: 3700,
    startedAt: Date.parse('2026-06-05T04:00:00.000Z'),
    endedAt: Date.parse('2026-06-05T05:01:40.000Z')
  },
  {
    id: 'session_4',
    taskTitle: '中断记录',
    projectName: '客户 B',
    status: 'abandoned',
    plannedDurationSeconds: 1500,
    actualDurationSeconds: 500,
    startedAt: Date.parse('2026-06-06T04:00:00.000Z'),
    endedAt: Date.parse('2026-06-06T04:08:20.000Z')
  },
  {
    id: 'session_recovery',
    taskTitle: '低谷重启',
    projectName: '客户 B',
    status: 'completed',
    restartFromReason: 'abandoned_retry',
    plannedDurationSeconds: 60,
    actualDurationSeconds: 60,
    startedAt: Date.parse('2026-06-06T04:10:00.000Z'),
    endedAt: Date.parse('2026-06-06T04:11:00.000Z')
  },
  {
    id: 'session_5',
    taskTitle: '上月工作',
    projectName: '客户 C',
    status: 'completed',
    plannedDurationSeconds: 1500,
    actualDurationSeconds: 1500,
    startedAt: Date.parse('2026-05-25T02:00:00.000Z'),
    endedAt: Date.parse('2026-05-25T02:25:00.000Z')
  }
];

const summary = createBillingSummary(sessions, settings, now);

assert.equal(summary.monthLabel, '2026年6月');
assert.equal(summary.totalFocusSeconds, 5800);
assert.equal(summary.totalBillableSeconds, 7200);
assert.equal(summary.totalAmount, 480);
assert.equal(summary.billableSessionCount, 3);
assert.equal(summary.projectCount, 2);
assert.equal(summary.averageSessionAmount, 160);
assert.equal(summary.topProjectName, '客户 B');
assert.equal(summary.projects[0].projectName, '客户 B');
assert.equal(summary.projects[0].billableSeconds, 4500);
assert.equal(summary.projects[0].amount, 300);
assert.equal(summary.projects[0].percent, 63);
assert.equal(summary.projects[1].projectName, '客户 A');
assert.equal(summary.projects[1].billableSeconds, 2700);
assert.equal(summary.projects[1].amount, 180);
assert.equal(createBillingInsight(summary), '客户 B 当前贡献最高，本月可结算 ¥480。');
assert.equal(createBillingSuggestion(summary), '本月可结算时长还偏少，适合先补齐高价值项目的连续工作块。');

const emptySummary = createBillingSummary([], settings, now);
assert.equal(emptySummary.totalAmount, 0);
assert.equal(emptySummary.topProjectName, '暂无项目');
assert.equal(createBillingInsight(emptySummary), '完成带项目归属的专注后，这里会自动生成本月可结算金额。');
assert.equal(createBillingSuggestion(emptySummary), '建议把客户或项目名填到任务里，之后每次专注都会进入对账汇总。');

// 上月账单周期:只统计 5 月记录,月份标签是上月
const previousSummary = createBillingSummary(sessions, settings, now, 'previous');
assert.equal(previousSummary.period, 'previous');
assert.equal(previousSummary.monthLabel, '2026年5月');
assert.equal(previousSummary.billableSessionCount, 1);
assert.equal(previousSummary.topProjectName, '客户 C');
assert.equal(previousSummary.totalBillableSeconds, 1800);
assert.equal(previousSummary.totalAmount, 120);

// 不可结算项目:仍出现在列表但金额为 0,不进入总额
const excludedSettings = {
  hourlyRate: 240,
  minimumBillableMinutes: 15,
  roundingMinutes: 15,
  currencySymbol: '¥',
  invoiceNote: '含 6 月项目开发工时',
  excludedProjects: ['客户 A']
};
const excludedSummary = createBillingSummary(sessions, excludedSettings, now);
assert.equal(excludedSummary.invoiceNote, '含 6 月项目开发工时');
assert.equal(excludedSummary.totalAmount, 300);
assert.equal(excludedSummary.billableSessionCount, 1);
assert.equal(excludedSummary.projectCount, 1);
assert.equal(excludedSummary.excludedProjectCount, 1);
assert.equal(excludedSummary.topProjectName, '客户 B');
const excludedProject = excludedSummary.projects.find((project) => project.projectName === '客户 A');
assert.equal(excludedProject.billable, false);
assert.equal(excludedProject.amount, 0);
assert.equal(excludedProject.billableSeconds, 0);
assert.equal(excludedProject.completedFocusCount, 2);

console.log('billing core tests passed');
