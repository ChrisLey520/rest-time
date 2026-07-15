import { Task } from '../models/Task';
import { createPlanningSnapshot, PlanningSnapshot } from '../utils/planningCore';
import { StatsService } from './StatsService';
import { StorageService } from './StorageService';
import { TaskService } from './TaskService';

export { PlanningSnapshot };

export class PlanningService {
  static async getSnapshot(tasks?: Task[]): Promise<PlanningSnapshot> {
    const sourceTasks = tasks ? tasks : await TaskService.listAll();
    const config = await StorageService.getConfig();
    const goalStats = await StatsService.getGoalStats();
    const weeklyStats = await StatsService.getWeeklyStats();
    const reviewStats = await StatsService.getReviewStats();

    return createPlanningSnapshot(sourceTasks, config, goalStats, weeklyStats, reviewStats);
  }
}
