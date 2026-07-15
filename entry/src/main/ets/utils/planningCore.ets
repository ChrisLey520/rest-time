import { PomodoroConfig } from '../models/PomodoroConfig';
import { Task } from '../models/Task';
import { GoalStats, ReviewStats, WeeklyStats } from './statsCore';

export type PlanningPace = 'empty' | 'light' | 'steady' | 'heavy';

export interface PlanningTaskCandidate {
  taskId: string;
  title: string;
  remainingFocusCount: number;
  progressPercent: number;
  priorityWeight: number;
  plannedForWeight: number;
  reason: string;
  payoff: string;
}

export interface PlanningSnapshot {
  pace: PlanningPace;
  activeTaskCount: number;
  remainingFocusCount: number;
  suggestedTodayFocusCount: number;
  suggestedTodayFocusMinutes: number;
  carryoverFocusCount: number;
  todayTaskCount: number;
  tomorrowTaskCount: number;
  laterTaskCount: number;
  unplannedTaskCount: number;
  highPriorityTaskCount: number;
  weeklyTargetFocusCount: number;
  weeklyCompletedFocusCount: number;
  weeklyRemainingFocusCount: number;
  bestFocusHourText: string;
  headline: string;
  description: string;
  nextTask?: PlanningTaskCandidate;
}

function activeTasks(tasks: Task[]): Task[] {
  return tasks.filter((task: Task) => task.status === 'active');
}

function remainingFocusCount(task: Task): number {
  return Math.max(0, task.estimatedFocusCount - task.completedFocusCount);
}

function progressPercent(task: Task): number {
  if (task.estimatedFocusCount <= 0) {
    return 100;
  }

  return Math.min(100, Math.floor(Math.max(0, task.completedFocusCount) * 100 / task.estimatedFocusCount));
}

function priorityWeight(task: Task): number {
  if (task.priority === 'high') {
    return 3;
  }

  if (task.priority === 'low') {
    return 1;
  }

  return 2;
}

function plannedForWeight(task: Task): number {
  if (task.plannedFor === 'today') {
    return 4;
  }

  if (task.plannedFor === 'tomorrow') {
    return 3;
  }

  if (task.plannedFor === 'later') {
    return 1;
  }

  return 2;
}

function candidateReason(task: Task, taskRemainingCount: number): string {
  const parts: string[] = [];
  if (task.priority === 'high') {
    parts.push('高优先级');
  }

  if (task.plannedFor === 'today') {
    parts.push('排在今天');
  } else if (task.plannedFor === 'tomorrow') {
    parts.push('排在明天');
  }

  if (taskRemainingCount === 1) {
    parts.push('只差 1 段就完成');
  }

  if (parts.length === 0) {
    return '当前最值得推进的一件事';
  }

  return parts.join(' · ');
}

function candidatePayoff(taskRemainingCount: number, taskProgressPercent: number, estimatedFocusCount: number): string {
  if (taskRemainingCount === 1) {
    return '完成这一段，任务就此收尾';
  }

  const nextProgressPercent = estimatedFocusCount > 0
    ? Math.min(100, taskProgressPercent + Math.floor(100 / estimatedFocusCount))
    : 100;
  return `完成这一段，任务进度推进到约 ${nextProgressPercent}%`;
}

function chooseNextTask(tasks: Task[]): PlanningTaskCandidate | undefined {
  let candidate: PlanningTaskCandidate | undefined = undefined;
  let candidateScore = -1;

  activeTasks(tasks).forEach((task: Task) => {
    const taskRemainingCount = remainingFocusCount(task);
    if (taskRemainingCount <= 0) {
      return;
    }

    const taskPriorityWeight = priorityWeight(task);
    const taskPlannedForWeight = plannedForWeight(task);
    const taskProgressPercent = progressPercent(task);
    const taskScore = taskPriorityWeight * 100 + taskPlannedForWeight * 20 + taskRemainingCount;
    if (!candidate || taskScore > candidateScore) {
      candidate = {
        taskId: task.id,
        title: task.title,
        remainingFocusCount: taskRemainingCount,
        progressPercent: taskProgressPercent,
        priorityWeight: taskPriorityWeight,
        plannedForWeight: taskPlannedForWeight,
        reason: candidateReason(task, taskRemainingCount),
        payoff: candidatePayoff(taskRemainingCount, taskProgressPercent, task.estimatedFocusCount)
      };
      candidateScore = taskScore;
    }
  });

  return candidate;
}

function bestFocusHourText(reviewStats: ReviewStats): string {
  if (reviewStats.bestFocusHour < 0 || reviewStats.bestFocusHourFocusSeconds <= 0) {
    return '--';
  }

  return `${reviewStats.bestFocusHour}:00`;
}

function paceFromRemaining(remainingFocusCount: number): PlanningPace {
  if (remainingFocusCount <= 0) {
    return 'empty';
  }

  if (remainingFocusCount <= 2) {
    return 'light';
  }

  if (remainingFocusCount <= 5) {
    return 'steady';
  }

  return 'heavy';
}

function headlineForSnapshot(pace: PlanningPace, nextTask?: PlanningTaskCandidate): string {
  if (nextTask) {
    return `先推进：${nextTask.title}`;
  }

  if (pace === 'empty') {
    return '今天可以先规划一件事';
  }

  return '先从最小的一段开始';
}

function descriptionForSnapshot(
  pace: PlanningPace,
  suggestedTodayFocusCount: number,
  carryoverFocusCount: number,
  bestHourText: string,
  highPriorityTaskCount: number
): string {
  if (pace === 'empty') {
    return '没有待办时，可以创建一个 1-2 次专注的小任务，让记录有明确归属。';
  }

  const hourHint = bestHourText === '--' ? '当前可用时段' : `${bestHourText} 附近`;
  const priorityHint = highPriorityTaskCount > 0 ? `优先处理 ${highPriorityTaskCount} 个高优先级任务，` : '';
  if (carryoverFocusCount > 0) {
    return `${priorityHint}建议今天完成 ${suggestedTodayFocusCount} 次，剩余 ${carryoverFocusCount} 次结转到明天，优先放在 ${hourHint}。`;
  }

  return `${priorityHint}建议今天完成 ${suggestedTodayFocusCount} 次，优先放在 ${hourHint}，完成后做一次轻复盘。`;
}

export function createPlanningSnapshot(
  tasks: Task[],
  config: PomodoroConfig,
  goalStats: GoalStats,
  weeklyStats: WeeklyStats,
  reviewStats: ReviewStats
): PlanningSnapshot {
  let totalRemainingFocusCount = 0;
  let todayTaskCount = 0;
  let tomorrowTaskCount = 0;
  let laterTaskCount = 0;
  let unplannedTaskCount = 0;
  let highPriorityTaskCount = 0;
  const currentActiveTasks = activeTasks(tasks);
  currentActiveTasks.forEach((task: Task) => {
    totalRemainingFocusCount += remainingFocusCount(task);
    if (task.priority === 'high') {
      highPriorityTaskCount += 1;
    }

    if (task.plannedFor === 'today') {
      todayTaskCount += 1;
    } else if (task.plannedFor === 'tomorrow') {
      tomorrowTaskCount += 1;
    } else if (task.plannedFor === 'later') {
      laterTaskCount += 1;
    } else {
      unplannedTaskCount += 1;
    }
  });

  const focusMinutes = Math.max(1, config.focusMinutes);
  const remainingGoalFocusCount = Math.ceil(goalStats.remainingSeconds / (focusMinutes * 60));
  const suggestedTodayFocusCount = totalRemainingFocusCount > 0
    ? Math.max(1, Math.min(totalRemainingFocusCount, Math.max(1, remainingGoalFocusCount)))
    : 0;
  const weeklyTargetFocusCount = Math.ceil(Math.max(0, config.dailyGoalMinutes * 7) / focusMinutes);
  const weeklyCompletedFocusCount = Math.max(0, weeklyStats.totalCompletedFocusCount);
  const weeklyRemainingFocusCount = Math.max(0, weeklyTargetFocusCount - weeklyCompletedFocusCount);
  const carryoverFocusCount = Math.max(0, totalRemainingFocusCount - suggestedTodayFocusCount);
  const pace = paceFromRemaining(totalRemainingFocusCount);
  const nextTask = chooseNextTask(tasks);
  const bestHourText = bestFocusHourText(reviewStats);

  return {
    pace,
    activeTaskCount: currentActiveTasks.length,
    remainingFocusCount: totalRemainingFocusCount,
    suggestedTodayFocusCount,
    suggestedTodayFocusMinutes: suggestedTodayFocusCount * focusMinutes,
    carryoverFocusCount,
    todayTaskCount,
    tomorrowTaskCount,
    laterTaskCount,
    unplannedTaskCount,
    highPriorityTaskCount,
    weeklyTargetFocusCount,
    weeklyCompletedFocusCount,
    weeklyRemainingFocusCount,
    bestFocusHourText: bestHourText,
    headline: headlineForSnapshot(pace, nextTask),
    description: descriptionForSnapshot(
      pace,
      suggestedTodayFocusCount,
      carryoverFocusCount,
      bestHourText,
      highPriorityTaskCount
    ),
    nextTask
  };
}
