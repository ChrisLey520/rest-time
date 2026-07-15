import assert from 'node:assert/strict';
import { createMonthlyReport } from './helpers/monthlyReportCore.mjs';

const monthlyStats = {
  monthLabel: '2026年6月',
  totalFocusSeconds: 9 * 3600 + 30 * 60,
  completedFocusCount: 18,
  abandonedFocusCount: 3,
  activeDayCount: 9,
  bestStreakDays: 4,
  completionRatePercent: 86,
  averageCompletedFocusSeconds: 1900,
  projects: [
    {
      projectName: '工作',
      focusSeconds: 6 * 3600,
      completedFocusCount: 11,
      percent: 63
    },
    {
      projectName: '学习',
      focusSeconds: 2 * 3600,
      completedFocusCount: 5,
      percent: 21
    }
  ]
};
const weeklyStats = {
  activeDayCount: 5
};
const reviewStats = {
  bestFocusHour: 10,
  bestFocusHourFocusSeconds: 4 * 3600
};
const previousMonthlyStats = {
  monthLabel: '2026年5月',
  totalFocusSeconds: 8 * 3600,
  completedFocusCount: 15,
  abandonedFocusCount: 4,
  activeDayCount: 8,
  bestStreakDays: 3,
  completionRatePercent: 79,
  averageCompletedFocusSeconds: 1900,
  projects: []
};

const report = createMonthlyReport(monthlyStats, weeklyStats, reviewStats, previousMonthlyStats);

assert.equal(report.title, '2026年6月专注报告');
assert.equal(report.subtitle, '项目投入、完成质量和下月建议');
assert.equal(report.summary, '本月完成 18 次专注，累计 9小时30分，活跃 9 天。');
assert.equal(report.insight, '工作 是本月投入最多的项目，占 63%，累计 6小时0分。');
assert.equal(report.suggestion, '本月完成率 86%，节奏已经较稳定，下月可以继续 把高价值任务放在 10:00 附近。');
assert.equal(report.exportTitle, '2026年6月 栖时月度报告');
assert.equal(report.metrics.length, 6);
assert.equal(report.metrics[0].label, '本月总计');
assert.equal(report.metrics[0].value, '9小时30分');
assert.equal(report.metrics[2].detail, '本周活跃 5/7 天');
assert.equal(report.metrics[4].label, '最佳连续');
assert.equal(report.metrics[4].value, '4 天');
assert.equal(report.metrics[4].detail, '连续性已经形成');
assert.equal(report.metrics[5].label, '投入趋势');
assert.equal(report.metrics[5].value, '较上月 +19%');
assert.equal(report.metrics[5].detail, '上月 8小时0分');
assert.equal(report.projects.length, 2);
assert.equal(report.projects[0].summary, '11 次 / 6小时0分');

const emptyReport = createMonthlyReport({
  monthLabel: '2026年7月',
  totalFocusSeconds: 0,
  completedFocusCount: 0,
  abandonedFocusCount: 0,
  activeDayCount: 0,
  bestStreakDays: 0,
  completionRatePercent: 0,
  averageCompletedFocusSeconds: 0,
  projects: []
}, {
  activeDayCount: 0
}, {
  bestFocusHour: -1,
  bestFocusHourFocusSeconds: 0
});

assert.equal(emptyReport.summary, '本月还没有完成的专注记录。先完成一段专注，报告会开始生成。');
assert.equal(emptyReport.insight, '项目投入分布会在完成带项目归属的任务后出现。');
assert.equal(emptyReport.suggestion, '建议先创建一个带项目归属的小任务，并完成 1 次专注。');
assert.equal(emptyReport.metrics[4].value, '--');
assert.equal(emptyReport.metrics[5].value, '继续累积记录');
assert.equal(emptyReport.metrics[5].detail, '完成两个月记录后出现');

console.log('monthly report core tests passed');
