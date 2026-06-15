const DAY_MS = 24 * 60 * 60 * 1000;

export function startOfDayMs(timestamp, offsetDays = 0) {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() + offsetDays);
  return date.getTime();
}

export function dayLabel(timestamp) {
  const date = new Date(timestamp);
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

export function normalizedFocusSeconds(seconds) {
  return seconds > 0 ? Math.floor(seconds) : 0;
}

export function completedSessionsInRange(sessions, startAt, endAt) {
  return sessions.filter((session) => {
    return session.status === 'completed' && session.endedAt >= startAt && session.endedAt < endAt;
  });
}

export function sumFocusSeconds(sessions) {
  return sessions.reduce((sum, session) => {
    return sum + normalizedFocusSeconds(session.actualDurationSeconds);
  }, 0);
}

export function createTodayStats(sessions, tasks, now) {
  const todayStart = startOfDayMs(now);
  const completedSessions = completedSessionsInRange(sessions, todayStart, now + 1);
  return {
    focusSeconds: sumFocusSeconds(completedSessions),
    completedFocusCount: completedSessions.length,
    completedTaskCount: tasks.filter((task) => {
      return task.status === 'completed' && !!task.completedAt && task.completedAt >= todayStart && task.completedAt <= now;
    }).length
  };
}

export function createGoalStats(dailyGoalMinutes, todayStats) {
  const goalSeconds = normalizedFocusSeconds(dailyGoalMinutes * 60);
  const progressPercent = goalSeconds > 0 ? Math.min(100, Math.floor(todayStats.focusSeconds * 100 / goalSeconds)) : 100;

  return {
    goalMinutes: normalizedFocusSeconds(dailyGoalMinutes),
    focusSeconds: todayStats.focusSeconds,
    progressPercent,
    remainingSeconds: Math.max(0, goalSeconds - todayStats.focusSeconds),
    isCompleted: goalSeconds === 0 || todayStats.focusSeconds >= goalSeconds
  };
}

export function createWeeklyStats(sessions, now) {
  const days = [];
  let totalFocusSeconds = 0;
  let totalCompletedFocusCount = 0;
  let bestDayLabel = '--';
  let bestDayFocusSeconds = 0;
  let activeDayCount = 0;

  for (let offset = -6; offset <= 0; offset += 1) {
    const startAt = startOfDayMs(now, offset);
    const endAt = offset < 0 ? startOfDayMs(now, offset + 1) : now + 1;
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
