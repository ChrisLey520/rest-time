import { FocusSession } from '../models/FocusSession';
import { startOfDayMs } from './statsCore';

export type RecordStage = 'empty' | 'light' | 'steady';

export const RECORD_STAGE_WINDOW_DAYS = 30;
export const RECORD_STAGE_STEADY_ACTIVE_DAYS = 3;
export const RECORD_STAGE_BILLING_PROJECT_SESSIONS = 3;

export interface RecordStageSnapshot {
  stage: RecordStage;
  activeDayCount: number;
  completedFocusCount: number;
  projectSessionCount: number;
  showMonthlyReport: boolean;
  showBilling: boolean;
  headline: string;
  description: string;
  unlockHint: string;
}

function isFormalCompleted(session: FocusSession): boolean {
  return session.status === 'completed'
    && session.countsAsFocus !== false
    && session.restartFromReason !== 'abandoned_retry';
}

function hasProject(session: FocusSession): boolean {
  return !!session.projectName && session.projectName.trim().length > 0;
}

export function createRecordStageSnapshot(sessions: FocusSession[], now: number): RecordStageSnapshot {
  const windowStart = startOfDayMs(now, -(RECORD_STAGE_WINDOW_DAYS - 1));
  const recentCompleted = sessions.filter((session: FocusSession) => {
    return isFormalCompleted(session) && session.endedAt >= windowStart && session.endedAt <= now;
  });

  const activeDayStarts: number[] = [];
  recentCompleted.forEach((session: FocusSession) => {
    const dayStart = startOfDayMs(session.endedAt);
    if (!activeDayStarts.includes(dayStart)) {
      activeDayStarts.push(dayStart);
    }
  });

  const activeDayCount = activeDayStarts.length;
  const completedFocusCount = recentCompleted.length;
  const projectSessionCount = recentCompleted.filter((session: FocusSession) => hasProject(session)).length;

  if (sessions.length === 0) {
    return {
      stage: 'empty',
      activeDayCount: 0,
      completedFocusCount: 0,
      projectSessionCount: 0,
      showMonthlyReport: false,
      showBilling: false,
      headline: '先完成第一段专注',
      description: '记录页会随着专注记录逐步展开：先看今天，再看本周，最后是月报和账单。',
      unlockHint: '完成 1 次专注后，这里会出现今日统计。'
    };
  }

  if (activeDayCount < RECORD_STAGE_STEADY_ACTIVE_DAYS) {
    const remainingDays = RECORD_STAGE_STEADY_ACTIVE_DAYS - activeDayCount;
    return {
      stage: 'light',
      activeDayCount,
      completedFocusCount,
      projectSessionCount,
      showMonthlyReport: false,
      showBilling: false,
      headline: '先把今天和本周稳住',
      description: '现在最重要的是连续记录，而不是报表。月报和账单会在记录稳定后自动出现。',
      unlockHint: `再活跃 ${remainingDays} 天解锁月度报告。`
    };
  }

  const showBilling = projectSessionCount >= RECORD_STAGE_BILLING_PROJECT_SESSIONS;
  const remainingProjectSessions = RECORD_STAGE_BILLING_PROJECT_SESSIONS - projectSessionCount;
  return {
    stage: 'steady',
    activeDayCount,
    completedFocusCount,
    projectSessionCount,
    showMonthlyReport: true,
    showBilling,
    headline: '记录已经可以复盘',
    description: '你的记录足够生成月度复盘。带项目归属的专注越多，账单和导出越有价值。',
    unlockHint: showBilling
      ? ''
      : `再完成 ${remainingProjectSessions} 次带项目归属的专注解锁客户账单。`
  };
}
