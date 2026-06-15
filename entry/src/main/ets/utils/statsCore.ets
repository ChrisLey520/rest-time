import { FocusSession } from '../models/FocusSession';
import { Task } from '../models/Task';

const DAY_MS = 24 * 60 * 60 * 1000;

export interface TodayStats {
  focusSeconds: number;
  completedFocusCount: number;
  completedTaskCount: number;
}

export interface GoalStats {
  goalMinutes: number;
  focusSeconds: number;
  progressPercent: number;
  remainingSeconds: number;
  isCompleted: boolean;
}

export interface DayStats {
  label: string;
  startAt: number;
  focusSeconds: number;
  completedFocusCount: number;
}

export interface WeeklyStats {
  days: DayStats[];
  totalFocusSeconds: number;
  totalCompletedFocusCount: number;
  bestDayLabel: string;
  bestDayFocusSeconds: number;
  activeDayCount: number;
}

export function startOfDayMs(timestamp: number, offsetDays: number = 0): number {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() + offsetDays);
  return date.getTime();
}

export function dayLabel(timestamp: number): string {
  const date = new Date(timestamp);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return `${month}/${day}`;
}

export function normalizedFocusSeconds(seconds: number): number {
  return seconds > 0 ? Math.floor(seconds) : 0;
}

export function completedSessionsInRange(sessions: FocusSession[], startAt: number, endAt: number): FocusSession[] {
  return sessions.filter((session: FocusSession) => {
    return session.status === 'completed' && session.endedAt >= startAt && session.endedAt < endAt;
  });
}

export function sumFocusSeconds(sessions: FocusSession[]): number {
  return sessions.reduce((sum: number, session: FocusSession) => {
    return sum + normalizedFocusSeconds(session.actualDurationSeconds);
  }, 0);
}

export function createTodayStats(sessions: FocusSession[], tasks: Task[], now: number): TodayStats {
  const todayStart = startOfDayMs(now);
  const completedSessions = completedSessionsInRange(sessions, todayStart, now + 1);
  return {
    focusSeconds: sumFocusSeconds(completedSessions),
    completedFocusCount: completedSessions.length,
    completedTaskCount: tasks.filter((task: Task) => {
      return task.status === 'completed' && !!task.completedAt && task.completedAt >= todayStart && task.completedAt <= now;
    }).length
  };
}

export function createGoalStats(dailyGoalMinutes: number, todayStats: TodayStats): GoalStats {
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

export function createWeeklyStats(sessions: FocusSession[], now: number): WeeklyStats {
  const days: DayStats[] = [];
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
    const stats: DayStats = {
      label: dayLabel(startAt),
      startAt,
      focusSeconds,
      completedFocusCount: completedSessions.length
    };
    days.push(stats);

    totalFocusSeconds += focusSeconds;
    totalCompletedFocusCount += completedSessions.length;
    if (focusSeconds > 0) {
      activeDayCount += 1;
    }

    if (focusSeconds > bestDayFocusSeconds) {
      bestDayFocusSeconds = focusSeconds;
      bestDayLabel = stats.label;
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
