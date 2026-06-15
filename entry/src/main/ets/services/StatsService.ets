import { FocusSession } from '../models/FocusSession';
import { Task } from '../models/Task';
import { SessionService } from './SessionService';
import { StorageService } from './StorageService';
import { TaskService } from './TaskService';

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

function startOfTodayMs(): number {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

function startOfDayMs(offsetDays: number): number {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() + offsetDays);
  return date.getTime();
}

function dayLabel(timestamp: number): string {
  const date = new Date(timestamp);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  return `${month}/${day}`;
}

function completedSessionsInRange(sessions: FocusSession[], startAt: number, endAt: number): FocusSession[] {
  return sessions.filter((session: FocusSession) => {
    return session.status === 'completed' && session.endedAt >= startAt && session.endedAt < endAt;
  });
}

function sumFocusSeconds(sessions: FocusSession[]): number {
  return sessions.reduce((sum: number, session: FocusSession) => {
    return sum + session.actualDurationSeconds;
  }, 0);
}

export class StatsService {
  static async getTodayStats(): Promise<TodayStats> {
    const sessions = await SessionService.listAll();
    const tasks = await TaskService.listAll();
    const todayStart = startOfTodayMs();
    const completedSessions = completedSessionsInRange(sessions, todayStart, Date.now() + 1);

    return {
      focusSeconds: sumFocusSeconds(completedSessions),
      completedFocusCount: completedSessions.length,
      completedTaskCount: tasks.filter((task: Task) => {
        return task.status === 'completed' && !!task.completedAt && task.completedAt >= todayStart;
      }).length
    };
  }

  static async getGoalStats(): Promise<GoalStats> {
    const config = await StorageService.getConfig();
    const todayStats = await StatsService.getTodayStats();
    const goalSeconds = config.dailyGoalMinutes * 60;
    const progressPercent = goalSeconds > 0 ? Math.min(100, Math.floor(todayStats.focusSeconds * 100 / goalSeconds)) : 100;

    return {
      goalMinutes: config.dailyGoalMinutes,
      focusSeconds: todayStats.focusSeconds,
      progressPercent,
      remainingSeconds: Math.max(0, goalSeconds - todayStats.focusSeconds),
      isCompleted: todayStats.focusSeconds >= goalSeconds
    };
  }

  static async getWeeklyStats(): Promise<WeeklyStats> {
    const sessions = await SessionService.listAll();
    const days: DayStats[] = [];
    let totalFocusSeconds = 0;
    let totalCompletedFocusCount = 0;
    let bestDayLabel = '--';
    let bestDayFocusSeconds = 0;
    let activeDayCount = 0;

    for (let offset = -6; offset <= 0; offset += 1) {
      const startAt = startOfDayMs(offset);
      const endAt = startAt + 24 * 60 * 60 * 1000;
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
}
