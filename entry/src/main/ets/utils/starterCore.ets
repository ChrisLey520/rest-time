import { FocusSession } from '../models/FocusSession';

export type StarterPlanRiskLevel = 'low' | 'medium' | 'high';
export type StarterPlanReason = 'fresh_start' | 'recent_abandon' | 'recent_away' | 'low_completion';

export interface StarterPlan {
  durationSeconds: number;
  riskLevel: StarterPlanRiskLevel;
  reason: StarterPlanReason;
  headline: string;
  description: string;
  guardLabel: string;
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
  if (riskLevel === 'high') {
    return {
      durationSeconds,
      riskLevel,
      reason,
      headline: `${minutes} 分钟保底启动`,
      description: '最近中断偏多，先别硬扛完整专注。只要求把任务摸到手里，完成后再接正常段。',
      guardLabel: '高风险'
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
      guardLabel: '易分心'
    };
  }

  return {
    durationSeconds,
    riskLevel,
    reason,
    headline: '标准专注启动',
    description: '当前节奏稳定，可以直接开始默认专注时长。',
    guardLabel: '稳定'
  };
}

export function createStarterPlan(sessions: FocusSession[], defaultFocusMinutes: number): StarterPlan {
  const defaultDurationSeconds = Math.max(1, Math.floor(defaultFocusMinutes)) * 60;
  const recent = recentSessions(sessions, 7);
  if (recent.length === 0) {
    return planText(defaultDurationSeconds, 'low', 'fresh_start');
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
