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

export function monthLabel(timestamp) {
  const date = new Date(timestamp);
  return `${date.getFullYear()}年${date.getMonth() + 1}月`;
}

export function normalizedFocusSeconds(seconds) {
  return seconds > 0 ? Math.floor(seconds) : 0;
}

export function completedSessionsInRange(sessions, startAt, endAt) {
  return sessions.filter((session) => {
    return session.status === 'completed'
      && session.countsAsFocus !== false
      && session.restartFromReason !== 'abandoned_retry'
      && session.endedAt >= startAt
      && session.endedAt < endAt;
  });
}

function isRecoverySession(session) {
  return session.status === 'completed'
    && (session.countsAsFocus === false || session.restartFromReason === 'abandoned_retry');
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

export function createReviewStats(sessions, now) {
  const startAt = startOfDayMs(now, -29);
  const recentSessions = sessions.filter((session) => {
    return session.endedAt >= startAt && session.endedAt <= now && !isRecoverySession(session);
  });
  const completedSessions = recentSessions.filter((session) => {
    return session.status === 'completed' && session.countsAsFocus !== false;
  });
  const totalFocusSeconds = sumFocusSeconds(completedSessions);
  const hourFocusSeconds = [];
  for (let index = 0; index < 24; index += 1) {
    hourFocusSeconds.push(0);
  }

  completedSessions.forEach((session) => {
    const hour = new Date(session.endedAt).getHours();
    hourFocusSeconds[hour] += normalizedFocusSeconds(session.actualDurationSeconds);
  });

  let bestFocusHour = -1;
  let bestFocusHourFocusSeconds = 0;
  hourFocusSeconds.forEach((seconds, hour) => {
    if (seconds > bestFocusHourFocusSeconds) {
      bestFocusHour = hour;
      bestFocusHourFocusSeconds = seconds;
    }
  });

  let currentStreakDays = 0;
  let lastRestOffset = 1;
  const todayFocusSeconds = sumFocusSeconds(completedSessionsInRange(sessions, startOfDayMs(now, 0), now + 1));
  if (todayFocusSeconds > 0) {
    currentStreakDays += 1;
  }

  for (let offset = -1; offset > -365; offset -= 1) {
    const startAt = startOfDayMs(now, offset);
    const endAt = startOfDayMs(now, offset + 1);
    const dayFocusSeconds = sumFocusSeconds(completedSessionsInRange(sessions, startAt, endAt));
    if (dayFocusSeconds > 0) {
      currentStreakDays += 1;
      continue;
    }

    if (lastRestOffset > 0 || lastRestOffset - offset >= 7) {
      lastRestOffset = offset;
      continue;
    }

    break;
  }

  return {
    currentStreakDays,
    bestFocusHour,
    bestFocusHourFocusSeconds,
    averageCompletedFocusSeconds: completedSessions.length > 0
      ? Math.round(totalFocusSeconds / completedSessions.length)
      : 0,
    completionRatePercent: recentSessions.length > 0
      ? Math.round(completedSessions.length * 100 / recentSessions.length)
      : 0
  };
}

export function createMonthlyStats(sessions, now, monthOffset = 0) {
  const monthStart = new Date(now);
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  monthStart.setMonth(monthStart.getMonth() + monthOffset);
  const startAt = monthStart.getTime();
  const monthEnd = new Date(startAt);
  monthEnd.setMonth(monthEnd.getMonth() + 1);
  const endAt = Math.min(monthEnd.getTime() - 1, now);
  const currentMonthSessions = sessions.filter((session) => {
    return session.endedAt >= startAt && session.endedAt <= endAt && !isRecoverySession(session);
  });
  const completedSessions = currentMonthSessions.filter((session) => {
    return session.status === 'completed' && session.countsAsFocus !== false;
  });
  const abandonedSessions = currentMonthSessions.filter((session) => {
    return session.status === 'abandoned';
  });
  const activeDayStarts = [];
  const projects = [];

  completedSessions.forEach((session) => {
    if (normalizedFocusSeconds(session.actualDurationSeconds) <= 0) {
      return;
    }

    const dayStart = startOfDayMs(session.endedAt);
    if (!activeDayStarts.includes(dayStart)) {
      activeDayStarts.push(dayStart);
    }

    const projectName = session.projectName && session.projectName.trim() ? session.projectName.trim() : '未归类';
    let project = projects.find((item) => item.projectName === projectName);
    if (!project) {
      project = {
        projectName,
        focusSeconds: 0,
        completedFocusCount: 0,
        percent: 0
      };
      projects.push(project);
    }

    project.focusSeconds += normalizedFocusSeconds(session.actualDurationSeconds);
    project.completedFocusCount += 1;
  });

  const totalFocusSeconds = sumFocusSeconds(completedSessions);
  projects.forEach((project) => {
    project.percent = totalFocusSeconds > 0 ? Math.round(project.focusSeconds * 100 / totalFocusSeconds) : 0;
  });
  projects.sort((left, right) => {
    if (right.focusSeconds !== left.focusSeconds) {
      return right.focusSeconds - left.focusSeconds;
    }

    return right.completedFocusCount - left.completedFocusCount;
  });

  const sortedDayStarts = activeDayStarts.slice().sort((left, right) => left - right);
  let bestStreakDays = sortedDayStarts.length > 0 ? 1 : 0;
  let currentStreakDays = bestStreakDays;
  for (let index = 1; index < sortedDayStarts.length; index += 1) {
    const previousDayStart = startOfDayMs(sortedDayStarts[index], -1);
    if (sortedDayStarts[index - 1] === previousDayStart) {
      currentStreakDays += 1;
    } else {
      currentStreakDays = 1;
    }

    if (currentStreakDays > bestStreakDays) {
      bestStreakDays = currentStreakDays;
    }
  }

  return {
    monthLabel: monthLabel(startAt),
    totalFocusSeconds,
    completedFocusCount: completedSessions.length,
    abandonedFocusCount: abandonedSessions.length,
    activeDayCount: activeDayStarts.length,
    bestStreakDays,
    completionRatePercent: currentMonthSessions.length > 0
      ? Math.round(completedSessions.length * 100 / currentMonthSessions.length)
      : 0,
    averageCompletedFocusSeconds: completedSessions.length > 0
      ? Math.round(totalFocusSeconds / completedSessions.length)
      : 0,
    projects
  };
}
