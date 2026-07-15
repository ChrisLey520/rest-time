import { SessionService } from './SessionService';
import { StorageService } from './StorageService';
import { TaskService } from './TaskService';
import {
  createGoalStats,
  createMonthlyStats,
  createReviewStats,
  createTodayStats,
  createWeeklyStats,
  DayStats,
  GoalStats,
  MonthlyStats,
  ProjectFocusStats,
  ReviewStats,
  TodayStats,
  WeeklyStats
} from '../utils/statsCore';

export { DayStats, GoalStats, MonthlyStats, ProjectFocusStats, ReviewStats, TodayStats, WeeklyStats };

export class StatsService {
  static async getTodayStats(): Promise<TodayStats> {
    const sessions = await SessionService.listAll();
    const tasks = await TaskService.listAll();
    return createTodayStats(sessions, tasks, Date.now());
  }

  static async getGoalStats(): Promise<GoalStats> {
    const config = await StorageService.getConfig();
    const todayStats = await StatsService.getTodayStats();
    return createGoalStats(config.dailyGoalMinutes, todayStats);
  }

  static async getWeeklyStats(): Promise<WeeklyStats> {
    const sessions = await SessionService.listAll();
    return createWeeklyStats(sessions, Date.now());
  }

  static async getReviewStats(): Promise<ReviewStats> {
    const sessions = await SessionService.listAll();
    return createReviewStats(sessions, Date.now());
  }

  static async getMonthlyStats(monthOffset: number = 0): Promise<MonthlyStats> {
    const sessions = await SessionService.listAll();
    return createMonthlyStats(sessions, Date.now(), monthOffset);
  }
}
