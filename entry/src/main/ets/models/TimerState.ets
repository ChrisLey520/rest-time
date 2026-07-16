export type TimerMode = 'focus' | 'break';
export type TimerStatus = 'idle' | 'running' | 'paused';
export type TimerPauseReason = 'manual' | 'background';
export type FocusGuardStatus = 'idle' | 'cooling';
export type FocusRestartReason = 'abandoned_retry';
export type StarterPlanRiskLevel = 'low' | 'medium' | 'high';
export type StarterPlanReason = 'fresh_start' | 'recent_abandon' | 'recent_away' | 'low_completion' | 'long_absence';
export type FocusIntegrityStatus = 'clean' | 'violated';
export type FocusIntegrityViolationReason = 'left_app' | 'app_terminated' | 'stale_presence';

export interface TimerState {
  id: string;
  mode: TimerMode;
  status: TimerStatus;
  taskId?: string;
  taskTitle?: string;
  projectName?: string;
  startedAt?: number;
  pausedAt?: number;
  pauseReason?: TimerPauseReason;
  lastPresenceAt?: number;
  awayStartedAt?: number;
  awayCount?: number;
  awaySeconds?: number;
  guardStatus?: FocusGuardStatus;
  guardStartedAt?: number;
  guardReason?: string;
  microActionText?: string;
  microActionStartedAt?: number;
  microActionDurationSeconds?: number;
  microActionCompletedCount?: number;
  microActionResetCount?: number;
  handoffNote?: string;
  focusGuardEnabled?: boolean;
  focusWhitelistLabel?: string;
  focusIntegrityStatus?: FocusIntegrityStatus;
  focusIntegrityViolationReason?: FocusIntegrityViolationReason;
  focusIntegrityViolationCount?: number;
  focusIntegrityViolatedAt?: number;
  returnProofStartedAt?: number;
  returnProofDurationSeconds?: number;
  returnProofRequiredCount?: number;
  returnProofCompletedCount?: number;
  returnProofSeconds?: number;
  starterPlanRiskLevel?: StarterPlanRiskLevel;
  starterPlanReason?: StarterPlanReason;
  starterPlanDurationSeconds?: number;
  recoveryStepIndex?: number;
  recoveryStepCount?: number;
  restartFromSessionId?: string;
  restartFromReason?: FocusRestartReason;
  expectedEndAt?: number;
  durationSeconds: number;
  accumulatedPausedMs: number;
}

export const idleTimerState: TimerState = {
  id: '',
  mode: 'focus',
  status: 'idle',
  durationSeconds: 0,
  accumulatedPausedMs: 0
};
