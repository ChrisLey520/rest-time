import assert from 'node:assert/strict';
import {
  createGoalStats,
  createMonthlyStats,
  createTodayStats,
  createReviewStats,
  createWeeklyStats,
  normalizedFocusSeconds,
  startOfDayMs
} from './helpers/statsCore.mjs';

const now = new Date('2026-06-15T12:00:00+08:00').getTime();
const todayStart = startOfDayMs(now);
const oneDay = 24 * 60 * 60 * 1000;
const sessions = [
  {
    id: 'today_1',
    projectName: '工作',
    actualDurationSeconds: 25 * 60,
    endedAt: todayStart + 9 * 60 * 60 * 1000,
    status: 'completed'
  },
  {
    id: 'today_2',
    projectName: '学习',
    actualDurationSeconds: 35 * 60,
    endedAt: todayStart + 10 * 60 * 60 * 1000,
    status: 'completed'
  },
  {
    id: 'today_abandoned',
    actualDurationSeconds: 5 * 60,
    endedAt: todayStart + 11 * 60 * 60 * 1000,
    status: 'abandoned'
  },
  {
    id: 'today_recovery',
    projectName: '工作',
    actualDurationSeconds: 60,
    endedAt: todayStart + 11 * 60 * 60 * 1000 + 5 * 60 * 1000,
    status: 'completed',
    restartFromReason: 'abandoned_retry'
  },
  {
    id: 'future_today',
    projectName: '工作',
    actualDurationSeconds: 45 * 60,
    endedAt: todayStart + 18 * 60 * 60 * 1000,
    status: 'completed'
  },
  {
    id: 'yesterday',
    projectName: '工作',
    actualDurationSeconds: 90 * 60,
    endedAt: todayStart - oneDay + 14 * 60 * 60 * 1000,
    status: 'completed'
  },
  {
    id: 'six_days_ago_negative',
    actualDurationSeconds: -30,
    endedAt: todayStart - 6 * oneDay + 14 * 60 * 60 * 1000,
    status: 'completed'
  },
  {
    id: 'seven_days_ago',
    projectName: '学习',
    actualDurationSeconds: 120 * 60,
    endedAt: todayStart - 7 * oneDay + 14 * 60 * 60 * 1000,
    status: 'completed'
  }
];
const tasks = [
  {
    id: 'task_today',
    status: 'completed',
    completedAt: todayStart + 8 * 60 * 60 * 1000
  },
  {
    id: 'task_future',
    status: 'completed',
    completedAt: todayStart + 19 * 60 * 60 * 1000
  },
  {
    id: 'task_old',
    status: 'completed',
    completedAt: todayStart - oneDay
  }
];

const todayStats = createTodayStats(sessions, tasks, now);
assert.equal(todayStats.focusSeconds, 60 * 60);
assert.equal(todayStats.completedFocusCount, 2);
assert.equal(todayStats.completedTaskCount, 1);

const goalStats = createGoalStats(120, todayStats);
assert.equal(goalStats.goalMinutes, 120);
assert.equal(goalStats.progressPercent, 50);
assert.equal(goalStats.remainingSeconds, 60 * 60);
assert.equal(goalStats.isCompleted, false);

const zeroGoalStats = createGoalStats(0, todayStats);
assert.equal(zeroGoalStats.progressPercent, 100);
assert.equal(zeroGoalStats.remainingSeconds, 0);
assert.equal(zeroGoalStats.isCompleted, true);

const weeklyStats = createWeeklyStats(sessions, now);
assert.equal(weeklyStats.days.length, 7);
assert.equal(weeklyStats.totalFocusSeconds, 150 * 60);
assert.equal(weeklyStats.totalCompletedFocusCount, 4);
assert.equal(weeklyStats.bestDayFocusSeconds, 90 * 60);
assert.equal(weeklyStats.activeDayCount, 2);
assert.equal(weeklyStats.days[0].focusSeconds, 0);
assert.equal(weeklyStats.days[6].focusSeconds, 60 * 60);
assert.equal(normalizedFocusSeconds(-1), 0);

const reviewStats = createReviewStats(sessions, now);
assert.equal(reviewStats.currentStreakDays, 2);
assert.equal(reviewStats.bestFocusHour, 14);
assert.equal(reviewStats.bestFocusHourFocusSeconds, (90 + 120) * 60);
assert.equal(reviewStats.averageCompletedFocusSeconds, Math.round((25 + 35 + 90 + 120) * 60 / 5));
assert.equal(reviewStats.completionRatePercent, Math.round(5 * 100 / 6));

const monthlyStats = createMonthlyStats(sessions, now);
assert.equal(monthlyStats.monthLabel, '2026年6月');
assert.equal(monthlyStats.totalFocusSeconds, (25 + 35 + 90 + 120) * 60);
assert.equal(monthlyStats.completedFocusCount, 5);
assert.equal(monthlyStats.abandonedFocusCount, 1);
assert.equal(monthlyStats.activeDayCount, 3);
assert.equal(monthlyStats.completionRatePercent, Math.round(5 * 100 / 6));
assert.equal(monthlyStats.averageCompletedFocusSeconds, Math.round((25 + 35 + 90 + 120) * 60 / 5));
assert.equal(monthlyStats.projects.length, 2);
assert.equal(monthlyStats.projects[0].projectName, '学习');
assert.equal(monthlyStats.projects[0].focusSeconds, (35 + 120) * 60);
assert.equal(monthlyStats.projects[0].completedFocusCount, 2);
assert.equal(monthlyStats.projects[0].percent, Math.round((35 + 120) * 100 / (25 + 35 + 90 + 120)));
assert.equal(monthlyStats.projects[1].projectName, '工作');
assert.equal(monthlyStats.bestStreakDays, 2);

// 上月统计:6 月的记录不应出现在 5 月窗口
const previousMonthlyStats = createMonthlyStats(sessions, now, -1);
assert.equal(previousMonthlyStats.monthLabel, '2026年5月');
assert.equal(previousMonthlyStats.completedFocusCount, 0);
assert.equal(previousMonthlyStats.bestStreakDays, 0);

console.log('stats core tests passed');
