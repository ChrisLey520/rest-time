import assert from 'node:assert/strict';

function startOfDayMs(timestamp) {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

function dayLabel(timestamp) {
  const date = new Date(timestamp);
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

function completedSessionsInRange(sessions, startAt, endAt) {
  return sessions.filter((session) => {
    return session.status === 'completed' && session.endedAt >= startAt && session.endedAt < endAt;
  });
}

function sumFocusSeconds(sessions) {
  return sessions.reduce((sum, session) => sum + session.actualDurationSeconds, 0);
}

function getTodayStats(sessions, tasks, now) {
  const todayStart = startOfDayMs(now);
  const completedSessions = completedSessionsInRange(sessions, todayStart, now + 1);
  return {
    focusSeconds: sumFocusSeconds(completedSessions),
    completedFocusCount: completedSessions.length,
    completedTaskCount: tasks.filter((task) => {
      return task.status === 'completed' && task.completedAt >= todayStart;
    }).length
  };
}

function getGoalStats(sessions, tasks, dailyGoalMinutes, now) {
  const todayStats = getTodayStats(sessions, tasks, now);
  const goalSeconds = dailyGoalMinutes * 60;
  return {
    goalMinutes: dailyGoalMinutes,
    focusSeconds: todayStats.focusSeconds,
    progressPercent: Math.min(100, Math.floor(todayStats.focusSeconds * 100 / goalSeconds)),
    remainingSeconds: Math.max(0, goalSeconds - todayStats.focusSeconds),
    isCompleted: todayStats.focusSeconds >= goalSeconds
  };
}

function getWeeklyStats(sessions, now) {
  const todayStart = startOfDayMs(now);
  const days = [];
  let totalFocusSeconds = 0;
  let totalCompletedFocusCount = 0;
  let bestDayLabel = '--';
  let bestDayFocusSeconds = 0;
  let activeDayCount = 0;

  for (let offset = -6; offset <= 0; offset += 1) {
    const startAt = todayStart + offset * 24 * 60 * 60 * 1000;
    const endAt = startAt + 24 * 60 * 60 * 1000;
    const completedSessions = completedSessionsInRange(sessions, startAt, endAt);
    const focusSeconds = sumFocusSeconds(completedSessions);
    const day = {
      label: dayLabel(startAt),
      startAt,
      focusSeconds,
      completedFocusCount: completedSessions.length
    };
    days.push(day);
    totalFocusSeconds += focusSeconds;
    totalCompletedFocusCount += completedSessions.length;
    if (focusSeconds > 0) {
      activeDayCount += 1;
    }
    if (focusSeconds > bestDayFocusSeconds) {
      bestDayFocusSeconds = focusSeconds;
      bestDayLabel = day.label;
    }
  }

  return {
    days,
    totalFocusSeconds,
    totalCompletedFocusCount,
    bestDayLabel,
    bestDayFocusSeconds,
    activeDayCount
  };
}

const now = new Date('2026-06-15T12:00:00+08:00').getTime();
const todayStart = startOfDayMs(now);
const oneDay = 24 * 60 * 60 * 1000;
const sessions = [
  {
    id: 'today_1',
    actualDurationSeconds: 25 * 60,
    endedAt: todayStart + 9 * 60 * 60 * 1000,
    status: 'completed'
  },
  {
    id: 'today_2',
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
    id: 'yesterday',
    actualDurationSeconds: 90 * 60,
    endedAt: todayStart - oneDay + 14 * 60 * 60 * 1000,
    status: 'completed'
  },
  {
    id: 'seven_days_ago',
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
    id: 'task_old',
    status: 'completed',
    completedAt: todayStart - oneDay
  }
];

const todayStats = getTodayStats(sessions, tasks, now);
assert.equal(todayStats.focusSeconds, 60 * 60);
assert.equal(todayStats.completedFocusCount, 2);
assert.equal(todayStats.completedTaskCount, 1);

const goalStats = getGoalStats(sessions, tasks, 120, now);
assert.equal(goalStats.progressPercent, 50);
assert.equal(goalStats.remainingSeconds, 60 * 60);
assert.equal(goalStats.isCompleted, false);

const weeklyStats = getWeeklyStats(sessions, now);
assert.equal(weeklyStats.days.length, 7);
assert.equal(weeklyStats.totalFocusSeconds, 150 * 60);
assert.equal(weeklyStats.totalCompletedFocusCount, 3);
assert.equal(weeklyStats.bestDayFocusSeconds, 90 * 60);
assert.equal(weeklyStats.activeDayCount, 2);
assert.equal(weeklyStats.days[6].focusSeconds, 60 * 60);

console.log('stats core tests passed');
