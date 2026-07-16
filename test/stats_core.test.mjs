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

// ---- 弹性节奏 streak ----
const streakSession = (dayOffset, minutes = 30) => ({
  id: `streak_${dayOffset}_${minutes}`,
  actualDurationSeconds: minutes * 60,
  endedAt: todayStart + dayOffset * oneDay + 12 * 60 * 60 * 1000,
  status: 'completed'
});

// 今天还没专注不算断:昨天+前天有记录,今天空白 → 保持 2 天
assert.equal(createReviewStats([streakSession(-1), streakSession(-2)], now).currentStreakDays, 2);

// 中间断 1 天用掉休息日,节奏不断:今天空白(今天不算断),-1 空白(消耗休息日),-2、-3 有记录
assert.equal(createReviewStats([streakSession(-2), streakSession(-3)], now).currentStreakDays, 2);

// 7 天内断第 2 天,节奏中断:-1 休息、-2 有、-3 空白(休息日已用) → 只算到 -2
assert.equal(createReviewStats([streakSession(-2), streakSession(-4)], now).currentStreakDays, 1);

// 跨 7 天可再次休息:-1 休息,-2..-7 连续 6 天,-8 空白(距上次休息 ≥7 天)再休,-9 有记录
assert.equal(createReviewStats([
  streakSession(-2), streakSession(-3), streakSession(-4), streakSession(-5),
  streakSession(-6), streakSession(-7), streakSession(-9)
], now).currentStreakDays, 7);

// 完全无记录 → 0
assert.equal(createReviewStats([], now).currentStreakDays, 0);

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
