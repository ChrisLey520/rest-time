import {
  createMonthlyReport,
  MonthlyReport,
  MonthlyReportMetric,
  MonthlyReportProject
} from '../utils/monthlyReportCore';
import { StatsService } from './StatsService';

export { MonthlyReport, MonthlyReportMetric, MonthlyReportProject };

export class MonthlyReportService {
  static async getCurrentReport(): Promise<MonthlyReport> {
    const monthlyStats = await StatsService.getMonthlyStats();
    const previousMonthlyStats = await StatsService.getMonthlyStats(-1);
    const weeklyStats = await StatsService.getWeeklyStats();
    const reviewStats = await StatsService.getReviewStats();

    return createMonthlyReport(monthlyStats, weeklyStats, reviewStats, previousMonthlyStats);
  }
}
