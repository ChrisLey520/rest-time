import assert from 'node:assert/strict';
import { createPlanningSnapshot } from './helpers/planningCore.mjs';

const config = {
  focusMinutes: 25,
  dailyGoalMinutes: 125
};
const goalStats = {
  remainingSeconds: 75 * 60
};
const weeklyStats = {
  totalCompletedFocusCount: 8
};
const reviewStats = {
  bestFocusHour: 10,
  bestFocusHourFocusSeconds: 70 * 60
};

{
  const snapshot = createPlanningSnapshot([
    {
      id: 'task_1',
      title: '写商业化方案',
      estimatedFocusCount: 5,
      completedFocusCount: 1,
      status: 'active',
      priority: 'normal',
      plannedFor: 'tomorrow'
    },
    {
      id: 'task_2',
      title: '准备发布素材',
      estimatedFocusCount: 2,
      completedFocusCount: 1,
      status: 'active',
      priority: 'high',
      plannedFor: 'today'
    },
    {
      id: 'task_3',
      title: '已完成旧任务',
      estimatedFocusCount: 1,
      completedFocusCount: 1,
      status: 'completed'
    },
    {
      id: 'task_4',
      title: '低优先级整理',
      estimatedFocusCount: 1,
      completedFocusCount: 0,
      status: 'active',
      priority: 'low',
      plannedFor: 'later'
    }
  ], config, goalStats, weeklyStats, reviewStats);

  assert.equal(snapshot.pace, 'heavy');
  assert.equal(snapshot.activeTaskCount, 3);
  assert.equal(snapshot.remainingFocusCount, 6);
  assert.equal(snapshot.suggestedTodayFocusCount, 3);
  assert.equal(snapshot.suggestedTodayFocusMinutes, 75);
  assert.equal(snapshot.carryoverFocusCount, 3);
  assert.equal(snapshot.todayTaskCount, 1);
  assert.equal(snapshot.tomorrowTaskCount, 1);
  assert.equal(snapshot.laterTaskCount, 1);
  assert.equal(snapshot.unplannedTaskCount, 0);
  assert.equal(snapshot.highPriorityTaskCount, 1);
  assert.equal(snapshot.weeklyTargetFocusCount, 35);
  assert.equal(snapshot.weeklyRemainingFocusCount, 27);
  assert.equal(snapshot.bestFocusHourText, '10:00');
  assert.equal(snapshot.nextTask.title, '准备发布素材');
  assert.equal(snapshot.nextTask.remainingFocusCount, 1);
  assert.equal(snapshot.nextTask.progressPercent, 50);
  assert.equal(snapshot.nextTask.priorityWeight, 3);
  assert.equal(snapshot.nextTask.plannedForWeight, 4);
  assert.equal(snapshot.nextTask.reason, '高优先级 · 排在今天 · 只差 1 段就完成');
  assert.equal(snapshot.nextTask.payoff, '完成这一段，任务就此收尾');
  assert.equal(snapshot.headline, '先推进：准备发布素材');
}

{
  const snapshot = createPlanningSnapshot([
    {
      id: 'task_plain',
      title: '普通任务',
      estimatedFocusCount: 4,
      completedFocusCount: 1,
      status: 'active'
    }
  ], config, goalStats, weeklyStats, reviewStats);

  assert.equal(snapshot.nextTask.reason, '当前最值得推进的一件事');
  assert.equal(snapshot.nextTask.payoff, '完成这一段，任务进度推进到约 50%');
}

{
  const snapshot = createPlanningSnapshot([], config, goalStats, weeklyStats, {
    bestFocusHour: -1,
    bestFocusHourFocusSeconds: 0
  });

  assert.equal(snapshot.pace, 'empty');
  assert.equal(snapshot.activeTaskCount, 0);
  assert.equal(snapshot.remainingFocusCount, 0);
  assert.equal(snapshot.suggestedTodayFocusCount, 0);
  assert.equal(snapshot.carryoverFocusCount, 0);
  assert.equal(snapshot.bestFocusHourText, '--');
  assert.equal(snapshot.nextTask, undefined);
}

console.log('planning core tests passed');
