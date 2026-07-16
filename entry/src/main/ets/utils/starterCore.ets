import { FocusSession } from '../models/FocusSession';
import { StarterPlanReason, StarterPlanRiskLevel } from '../models/TimerState';

export { StarterPlanReason, StarterPlanRiskLevel };

export const ABSENCE_THRESHOLD_DAYS = 2;

export interface StarterPlan {
  durationSeconds: number;
  riskLevel: StarterPlanRiskLevel;
  reason: StarterPlanReason;
  headline: string;
  description: string;
  guardLabel: string;
  absenceDays: number;
}

function recentSessions(sessions: FocusSession[], limit: number): FocusSession[] {
  return sessions
    .slice()
    .sort((left: FocusSession, right: FocusSession) => right.endedAt - left.endedAt)
    .slice(0, limit);
}

function hasRecentAway(session: FocusSession): boolean {
  return (session.awaySeconds ? session.awaySeconds : 0) >= 30
    || (session.returnProofRequiredCount ? session.returnProofRequiredCount : 0) > 0;
}

function planText(durationSeconds: number, riskLevel: StarterPlanRiskLevel, reason: StarterPlanReason): StarterPlan {
  const minutes = Math.max(1, Math.floor(durationSeconds / 60));
  if (reason === 'long_absence') {
    return {
      durationSeconds,
      riskLevel,
      reason,
      headline: `${minutes} 分钟回归启动`,
      description: '回来了就好。不用补上错过的天数，先用一小段找回手感，今天只要这一段就算赢。',
      guardLabel: '欢迎回来',
      absenceDays: 0
    };
  }

  if (riskLevel === 'high') {
    return {
      durationSeconds,
      riskLevel,
      reason,
      headline: `${minutes} 分钟保底启动`,
      description: '最近中断偏多，先别硬扛完整专注。只要求把任务摸到手里，完成后再接正常段。',
      guardLabel: '高风险',
      absenceDays: 0
    };
  }

  if (riskLevel === 'medium') {
    return {
      durationSeconds,
      riskLevel,
      reason,
      headline: `${minutes} 分钟稳住启动`,
      description: reason === 'recent_away'
        ? '最近有离场记录，先用短段确认自己真的回来了，再进入完整专注。'
        : '最近完成不够稳，先做一段更容易完成的启动段。',
      guardLabel: '易分心',
      absenceDays: 0
    };
  }

  return {
    durationSeconds,
    riskLevel,
    reason,
    headline: '标准专注启动',
    description: '当前节奏稳定，可以直接开始默认专注时长。',
    guardLabel: '稳定',
    absenceDays: 0
  };
}

function daysBetween(earlier: number, later: number): number {
  const earlierDay = new Date(earlier);
  earlierDay.setHours(0, 0, 0, 0);
  const laterDay = new Date(later);
  laterDay.setHours(0, 0, 0, 0);
  return Math.round((laterDay.getTime() - earlierDay.getTime()) / (24 * 60 * 60 * 1000));
}

export function absenceDaysSinceLastSession(sessions: FocusSession[], now: number): number {
  if (sessions.length === 0) {
    return 0;
  }

  let lastEndedAt = 0;
  sessions.forEach((session: FocusSession) => {
    if (session.endedAt > lastEndedAt) {
      lastEndedAt = session.endedAt;
    }
  });

  return Math.max(0, daysBetween(lastEndedAt, now));
}

export function createStarterPlan(
  sessions: FocusSession[],
  defaultFocusMinutes: number,
  now: number = 0
): StarterPlan {
  const defaultDurationSeconds = Math.max(1, Math.floor(defaultFocusMinutes)) * 60;
  const recent = recentSessions(sessions, 7);
  if (recent.length === 0) {
    return planText(defaultDurationSeconds, 'low', 'fresh_start');
  }

  // 缺席 ≥2 天后回归：优先于其他风险判断。此刻不需要审判，需要一个 5 分钟的台阶。
  if (now > 0) {
    const absenceDays = absenceDaysSinceLastSession(sessions, now);
    if (absenceDays >= ABSENCE_THRESHOLD_DAYS) {
      const plan = planText(Math.min(defaultDurationSeconds, 5 * 60), 'high', 'long_absence');
      plan.absenceDays = absenceDays;
      return plan;
    }
  }

  const abandonedCount = recent.filter((session: FocusSession) => session.status === 'abandoned').length;
  const awayCount = recent.filter((session: FocusSession) => hasRecentAway(session)).length;
  const completedCount = recent.filter((session: FocusSession) => {
    return session.status === 'completed'
      && session.countsAsFocus !== false
      && session.restartFromReason !== 'abandoned_retry';
  }).length;
  const completionRate = Math.floor(completedCount * 100 / recent.length);

  if (abandonedCount >= 2 || completionRate < 50) {
    return planText(Math.min(defaultDurationSeconds, 5 * 60), 'high', 'recent_abandon');
  }

  if (awayCount >= 2) {
    return planText(Math.min(defaultDurationSeconds, 10 * 60), 'medium', 'recent_away');
  }

  if (completionRate < 70) {
    return planText(Math.min(defaultDurationSeconds, 15 * 60), 'medium', 'low_completion');
  }

  return planText(defaultDurationSeconds, 'low', 'fresh_start');
}
