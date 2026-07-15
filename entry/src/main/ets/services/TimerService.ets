import { FocusAbandonReason, FocusSession } from '../models/FocusSession';
import {
  FocusIntegrityViolationReason,
  StarterPlanReason,
  StarterPlanRiskLevel,
  idleTimerState,
  TimerState
} from '../models/TimerState';
import { createId } from '../utils/id';
import { SessionService } from './SessionService';
import { StorageService } from './StorageService';
import { TaskService } from './TaskService';
import { NotificationService } from './NotificationService';
import { PomodoroProgressService } from './PomodoroProgressService';
import { ReminderService } from './ReminderService';
import {
  TIME_COIN_DAILY_CAP,
  TIME_COIN_MAX_PER_SESSION,
  awardTimeCoins
} from '../utils/timeCoinCore';

const PRESENCE_GRACE_MS = 5000;
const PRESENCE_SAVE_INTERVAL_MS = 2000;
const RETURN_PROOF_TRIGGER_SECONDS = 15;
export const RETURN_PROOF_SECONDS = 60;
export const FOCUS_GUARD_COOLDOWN_SECONDS = 20;
export const MICRO_ACTION_SECONDS = 3 * 60;
export const RECOVERY_GATE_STEP_SECONDS: number[] = [60, 3 * 60, 5 * 60];
const FOCUS_WHITELIST_LABEL = '栖时前台';

function cloneIdleState(): TimerState {
  return {
    id: '',
    mode: 'focus',
    status: 'idle',
    durationSeconds: 0,
    accumulatedPausedMs: 0
  };
}

function createInitialMicroAction(taskTitle?: string): string {
  const title = taskTitle && taskTitle.trim() ? taskTitle.trim() : '这件事';
  if (title === '自由专注') {
    return '先写下这 3 分钟要推进的一小步';
  }

  return `先推进「${title}」最小的一步`;
}

function createSmallerMicroAction(currentText?: string): string {
  const text = currentText && currentText.trim() ? currentText.trim() : '当前任务';
  return `只做 3 分钟：${text}`;
}

function createHandoffNote(state: TimerState, reason?: FocusAbandonReason): string {
  const actionText = state.microActionText && state.microActionText.trim()
    ? state.microActionText.trim()
    : createInitialMicroAction(state.taskTitle);
  if (reason === 'blocked') {
    return `下次先解除卡点：${actionText}`;
  }

  if (reason === 'tired') {
    return `下次只做低负担一步：${actionText}`;
  }

  if (reason === 'distracted') {
    return `下次先回到这一小步：${actionText}`;
  }

  if (reason === 'wrong_task') {
    return `下次先确认任务是否正确：${actionText}`;
  }

  return `下次从这里继续：${actionText}`;
}

export interface TimerStartResult {
  didStart: boolean;
  state: TimerState;
  message: string;
  recoveryRequiredSessionId?: string;
}

export interface RecoveryGate {
  isRequired: boolean;
  session?: FocusSession;
  nextStepIndex: number;
  nextDurationSeconds: number;
}

export class TimerService {
  static isFocusStartBlocked(state: TimerState): boolean {
    return state.status === 'running' || state.status === 'paused' || state.mode === 'break';
  }

  static async canStartFocus(): Promise<boolean> {
    const state = await TimerService.restore();
    return !TimerService.isFocusStartBlocked(state);
  }

  static nextRecoveryStepIndex(session?: FocusSession): number {
    if (!session) {
      return -1;
    }

    if (session.status === 'abandoned') {
      return 0;
    }

    if (session.status === 'completed' && session.restartFromReason === 'abandoned_retry') {
      const stepIndex = session.recoveryStepIndex !== undefined
        ? session.recoveryStepIndex
        : TimerService.inferRecoveryStepIndex(session.actualDurationSeconds);
      return stepIndex + 1;
    }

    return -1;
  }

  static recoveryDurationSecondsForStep(stepIndex: number): number {
    if (stepIndex < 0) {
      return RECOVERY_GATE_STEP_SECONDS[RECOVERY_GATE_STEP_SECONDS.length - 1];
    }

    if (stepIndex >= RECOVERY_GATE_STEP_SECONDS.length) {
      return RECOVERY_GATE_STEP_SECONDS[RECOVERY_GATE_STEP_SECONDS.length - 1];
    }

    return RECOVERY_GATE_STEP_SECONDS[stepIndex];
  }

  static async getRecoveryGate(): Promise<RecoveryGate> {
    const sessions = await SessionService.listRecent(1);
    const session = sessions.length > 0 ? sessions[0] : undefined;
    const stepIndex = TimerService.nextRecoveryStepIndex(session);
    const isRequired = stepIndex >= 0 && stepIndex < RECOVERY_GATE_STEP_SECONDS.length;
    return {
      isRequired,
      session,
      nextStepIndex: isRequired ? stepIndex : -1,
      nextDurationSeconds: isRequired ? TimerService.recoveryDurationSecondsForStep(stepIndex) : 0
    };
  }

  private static inferRecoveryStepIndex(actualDurationSeconds: number): number {
    for (let index = 0; index < RECOVERY_GATE_STEP_SECONDS.length; index += 1) {
      if (actualDurationSeconds <= RECOVERY_GATE_STEP_SECONDS[index]) {
        return index;
      }
    }

    return RECOVERY_GATE_STEP_SECONDS.length - 1;
  }

  static async tryStartFocus(
    durationSeconds?: number,
    taskId?: string,
    taskTitle?: string,
    projectName?: string,
    restartFromSessionId?: string,
    starterPlanRiskLevel?: StarterPlanRiskLevel,
    starterPlanReason?: StarterPlanReason,
    recoveryStepIndex?: number,
    recoveryStepCount?: number
  ): Promise<TimerStartResult> {
    const currentState = await TimerService.restore();
    if (TimerService.isFocusStartBlocked(currentState)) {
      const blockedResult: TimerStartResult = {
        didStart: false,
        state: currentState,
        message: TimerService.focusStartBlockedMessage(currentState)
      };
      return blockedResult;
    }

    const recoveryGate = await TimerService.getRecoveryGate();
    if (recoveryGate.isRequired && !restartFromSessionId) {
      const blockedResult: TimerStartResult = {
        didStart: false,
        state: currentState,
        message: `先完成 ${Math.max(1, Math.floor(recoveryGate.nextDurationSeconds / 60))} 分钟恢复，再回到正常专注`,
        recoveryRequiredSessionId: recoveryGate.session ? recoveryGate.session.id : undefined
      };
      return blockedResult;
    }

    let nextDurationSeconds = durationSeconds;
    let nextRecoveryStepIndex = recoveryStepIndex;
    let nextRecoveryStepCount = recoveryStepCount;
    if (recoveryGate.isRequired) {
      nextDurationSeconds = recoveryGate.nextDurationSeconds;
      nextRecoveryStepIndex = recoveryGate.nextStepIndex;
      nextRecoveryStepCount = RECOVERY_GATE_STEP_SECONDS.length;
    }

    const state = await TimerService.createFocusTimer(
      nextDurationSeconds,
      taskId,
      taskTitle,
      projectName,
      restartFromSessionId,
      starterPlanRiskLevel,
      starterPlanReason,
      nextRecoveryStepIndex,
      nextRecoveryStepCount
    );
    const startedResult: TimerStartResult = {
      didStart: true,
      state,
      message: ''
    };
    return startedResult;
  }

  static async startFocus(
    durationSeconds?: number,
    taskId?: string,
    taskTitle?: string,
    projectName?: string,
    restartFromSessionId?: string,
    starterPlanRiskLevel?: StarterPlanRiskLevel,
    starterPlanReason?: StarterPlanReason,
    recoveryStepIndex?: number,
    recoveryStepCount?: number
  ): Promise<TimerState> {
    const result = await TimerService.tryStartFocus(
      durationSeconds,
      taskId,
      taskTitle,
      projectName,
      restartFromSessionId,
      starterPlanRiskLevel,
      starterPlanReason,
      recoveryStepIndex,
      recoveryStepCount
    );
    return result.state;
  }

  static async tryStartBreak(durationSeconds?: number): Promise<TimerStartResult> {
    const currentState = await TimerService.restore();
    if (currentState.status !== 'idle') {
      const blockedResult: TimerStartResult = {
        didStart: false,
        state: currentState,
        message: currentState.mode === 'break' ? '歇息正在进行' : '专注正在进行'
      };
      return blockedResult;
    }

    const state = await TimerService.createBreakTimer(currentState, durationSeconds);
    const startedResult: TimerStartResult = {
      didStart: true,
      state,
      message: ''
    };
    return startedResult;
  }

  static async startBreak(durationSeconds?: number): Promise<TimerState> {
    const result = await TimerService.tryStartBreak(durationSeconds);
    return result.state;
  }

  static async shrinkCurrentFocusRemaining(remainingSeconds: number): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (state.status === 'idle' || state.mode !== 'focus' || !state.startedAt || !state.expectedEndAt) {
      return state;
    }

    const ignoredRemainingSeconds = remainingSeconds;
    if (ignoredRemainingSeconds < 1) {
      return state;
    }

    // Hard focus cannot be shortened into a successful completion. Ending early is a failed focus.
    return state;
  }

  static hasFocusIntegrityViolation(state: TimerState): boolean {
    return state.focusIntegrityStatus === 'violated';
  }

  private static markFocusIntegrityViolation(
    state: TimerState,
    reason: FocusIntegrityViolationReason,
    now: number
  ): void {
    state.focusGuardEnabled = true;
    state.focusWhitelistLabel = state.focusWhitelistLabel ? state.focusWhitelistLabel : FOCUS_WHITELIST_LABEL;
    state.focusIntegrityStatus = 'violated';
    state.focusIntegrityViolationReason = reason;
    state.focusIntegrityViolationCount = (state.focusIntegrityViolationCount ? state.focusIntegrityViolationCount : 0) + 1;
    state.focusIntegrityViolatedAt = now;
    state.handoffNote = state.handoffNote && state.handoffNote.trim()
      ? state.handoffNote.trim()
      : createHandoffNote(state, reason === 'stale_presence' ? 'distracted' : undefined);
  }

  private static registerAwayPause(
    state: TimerState,
    pausedAt: number,
    violationReason: FocusIntegrityViolationReason = 'left_app',
    awayStartedAt?: number
  ): void {
    state.status = 'paused';
    state.pausedAt = pausedAt;
    state.pauseReason = 'background';
    state.awayStartedAt = awayStartedAt !== undefined ? awayStartedAt : pausedAt;
    state.awayCount = (state.awayCount ? state.awayCount : 0) + 1;
    state.guardStatus = 'idle';
    state.guardStartedAt = undefined;
    state.guardReason = undefined;
    TimerService.markFocusIntegrityViolation(state, violationReason, Date.now());
  }

  private static closeAwayPause(state: TimerState, now: number): number {
    if (state.pauseReason !== 'background') {
      return 0;
    }

    const awayStartedAt = state.awayStartedAt !== undefined ? state.awayStartedAt : state.pausedAt;
    if (awayStartedAt === undefined) {
      return 0;
    }
    const awayMs = Math.max(0, now - awayStartedAt);
    const awaySeconds = Math.floor(awayMs / 1000);
    state.awaySeconds = (state.awaySeconds ? state.awaySeconds : 0) + awaySeconds;
    state.awayStartedAt = undefined;
    return awayMs;
  }

  private static requireReturnProof(state: TimerState, now: number): void {
    state.returnProofRequiredCount = (state.returnProofRequiredCount ? state.returnProofRequiredCount : 0) + 1;
    state.returnProofStartedAt = now;
    state.returnProofDurationSeconds = RETURN_PROOF_SECONDS;

    if (state.expectedEndAt) {
      const proofReadyAt = now + RETURN_PROOF_SECONDS * 1000;
      if (state.expectedEndAt < proofReadyAt) {
        state.expectedEndAt = proofReadyAt;
      }
    }
  }

  private static normalizeReturnProof(state: TimerState, now: number): boolean {
    if (!state.returnProofStartedAt || !state.returnProofDurationSeconds) {
      return false;
    }

    const elapsedSeconds = Math.floor((now - state.returnProofStartedAt) / 1000);
    if (elapsedSeconds < state.returnProofDurationSeconds) {
      return false;
    }

    state.returnProofCompletedCount = (state.returnProofCompletedCount ? state.returnProofCompletedCount : 0) + 1;
    state.returnProofSeconds = (state.returnProofSeconds ? state.returnProofSeconds : 0) + state.returnProofDurationSeconds;
    state.returnProofStartedAt = undefined;
    state.returnProofDurationSeconds = undefined;
    return true;
  }

  static returnProofRemainingSeconds(state: TimerState, now: number = Date.now()): number {
    if (!state.returnProofStartedAt || !state.returnProofDurationSeconds) {
      return 0;
    }

    const effectiveNow = state.status === 'paused' && state.pausedAt ? state.pausedAt : now;
    const elapsedSeconds = Math.floor((effectiveNow - state.returnProofStartedAt) / 1000);
    return Math.max(0, state.returnProofDurationSeconds - elapsedSeconds);
  }

  private static async createFocusTimer(
    durationSeconds?: number,
    taskId?: string,
    taskTitle?: string,
    projectName?: string,
    restartFromSessionId?: string,
    starterPlanRiskLevel?: StarterPlanRiskLevel,
    starterPlanReason?: StarterPlanReason,
    recoveryStepIndex?: number,
    recoveryStepCount?: number
  ): Promise<TimerState> {
    const config = await StorageService.getConfig();
    const plannedDurationSeconds = durationSeconds ? durationSeconds : config.focusMinutes * 60;
    const now = Date.now();
    const state: TimerState = {
      id: createId('timer'),
      mode: 'focus',
      status: 'running',
      taskId,
      taskTitle,
      projectName,
      startedAt: now,
      lastPresenceAt: now,
      guardStatus: 'idle',
      microActionText: createInitialMicroAction(taskTitle),
      microActionStartedAt: now,
      microActionDurationSeconds: MICRO_ACTION_SECONDS,
      microActionCompletedCount: 0,
      microActionResetCount: 0,
      focusGuardEnabled: true,
      focusWhitelistLabel: FOCUS_WHITELIST_LABEL,
      focusIntegrityStatus: 'clean',
      starterPlanRiskLevel,
      starterPlanReason,
      starterPlanDurationSeconds: plannedDurationSeconds,
      recoveryStepIndex,
      recoveryStepCount,
      restartFromSessionId,
      restartFromReason: restartFromSessionId ? 'abandoned_retry' : undefined,
      expectedEndAt: now + plannedDurationSeconds * 1000,
      durationSeconds: plannedDurationSeconds,
      accumulatedPausedMs: 0
    };

    await StorageService.saveTimerState(state);
    await ReminderService.scheduleForTimer(state);
    return state;
  }

  static async startAbandonGuard(reason: string): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (state.status === 'idle' || state.mode !== 'focus' || !state.startedAt) {
      return state;
    }

    state.guardStatus = 'cooling';
    state.guardStartedAt = Date.now();
    state.guardReason = reason;
    state.handoffNote = createHandoffNote(state, TimerService.normalizeAbandonReason(reason));
    await StorageService.saveTimerState(state);
    return state;
  }

  private static normalizeAbandonReason(reason?: string): FocusAbandonReason | undefined {
    if (reason === 'tired') {
      return 'tired';
    }

    if (reason === 'blocked') {
      return 'blocked';
    }

    if (reason === 'wrong_task') {
      return 'wrong_task';
    }

    if (reason === 'other') {
      return 'other';
    }

    if (reason === 'distracted') {
      return 'distracted';
    }

    return undefined;
  }

  static async cancelAbandonGuard(): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (state.guardStatus === 'cooling') {
      state.guardStatus = 'idle';
      state.guardStartedAt = undefined;
      state.guardReason = undefined;
      await StorageService.saveTimerState(state);
    }

    return state;
  }

  static abandonGuardRemainingSeconds(state: TimerState, now: number = Date.now()): number {
    if (state.guardStatus !== 'cooling' || !state.guardStartedAt) {
      return 0;
    }

    const elapsedSeconds = Math.floor((now - state.guardStartedAt) / 1000);
    return Math.max(0, FOCUS_GUARD_COOLDOWN_SECONDS - elapsedSeconds);
  }

  static microActionRemainingSeconds(state: TimerState, now: number = Date.now()): number {
    if (!state.microActionStartedAt || !state.microActionDurationSeconds) {
      return 0;
    }

    const effectiveNow = state.status === 'paused' && state.pausedAt ? state.pausedAt : now;
    const elapsedSeconds = Math.floor((effectiveNow - state.microActionStartedAt) / 1000);
    return Math.max(0, state.microActionDurationSeconds - elapsedSeconds);
  }

  static async completeMicroAction(): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (state.status === 'idle' || state.mode !== 'focus') {
      return state;
    }

    state.microActionCompletedCount = (state.microActionCompletedCount ? state.microActionCompletedCount : 0) + 1;
    state.microActionText = createSmallerMicroAction(state.microActionText);
    state.microActionStartedAt = Date.now();
    state.microActionDurationSeconds = MICRO_ACTION_SECONDS;
    await StorageService.saveTimerState(state);
    return state;
  }

  static async resetMicroAction(text?: string): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (state.status === 'idle' || state.mode !== 'focus') {
      return state;
    }

    state.microActionResetCount = (state.microActionResetCount ? state.microActionResetCount : 0) + 1;
    state.microActionText = text && text.trim()
      ? text.trim()
      : createSmallerMicroAction(state.taskTitle ? state.taskTitle : state.microActionText);
    state.microActionStartedAt = Date.now();
    state.microActionDurationSeconds = MICRO_ACTION_SECONDS;
    await StorageService.saveTimerState(state);
    return state;
  }

  static awaySeconds(state: TimerState, now: number = Date.now()): number {
    const savedAwaySeconds = state.awaySeconds ? state.awaySeconds : 0;
    if (state.pauseReason !== 'background') {
      return savedAwaySeconds;
    }

    const awayStartedAt = state.awayStartedAt !== undefined ? state.awayStartedAt : state.pausedAt;
    if (awayStartedAt === undefined) {
      return savedAwaySeconds;
    }

    return savedAwaySeconds + Math.floor(Math.max(0, now - awayStartedAt) / 1000);
  }

  static async markPresence(): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (state.status === 'running' && state.mode === 'focus') {
      const normalizedState = await TimerService.pauseStalePresence(state);
      if (normalizedState.status !== 'running') {
        return normalizedState;
      }

      const now = Date.now();
      const didCompleteReturnProof = TimerService.normalizeReturnProof(normalizedState, now);
      const lastPresenceAt = normalizedState.lastPresenceAt ? normalizedState.lastPresenceAt : now;
      if (didCompleteReturnProof || now - lastPresenceAt >= PRESENCE_SAVE_INTERVAL_MS) {
        normalizedState.lastPresenceAt = now;
        await StorageService.saveTimerState(normalizedState);
      }

      return normalizedState;
    }

    return state;
  }

  private static async createBreakTimer(currentState: TimerState, durationSeconds?: number): Promise<TimerState> {
    const config = await StorageService.getConfig();
    const plannedDurationSeconds = durationSeconds
      ? durationSeconds
      : currentState.mode === 'break' && currentState.durationSeconds > 0
        ? currentState.durationSeconds
        : config.shortBreakMinutes * 60;
    const breakTitle = currentState.mode === 'break' && currentState.taskTitle ? currentState.taskTitle : '歇息';
    const now = Date.now();
    const state: TimerState = {
      id: createId('timer'),
      mode: 'break',
      status: 'running',
      taskTitle: breakTitle,
      startedAt: now,
      expectedEndAt: now + plannedDurationSeconds * 1000,
      durationSeconds: plannedDurationSeconds,
      accumulatedPausedMs: 0
    };

    await StorageService.saveTimerState(state);
    await ReminderService.scheduleForTimer(state);
    return state;
  }

  private static focusStartBlockedMessage(state: TimerState): string {
    if (state.mode === 'break' && state.status === 'idle') {
      return '先处理当前歇息，再开始新的专注';
    }

    if (state.mode === 'break') {
      return '歇息正在进行，已切到专注页';
    }

    if (state.status === 'paused') {
      return '已有未收束的专注，已切到专注页';
    }

    return '已有进行中的专注，已切到专注页';
  }

  static async pause(): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (state.status !== 'running') {
      return state;
    }

    if (state.mode === 'focus') {
      return state;
    }

    state.status = 'paused';
    state.pausedAt = Date.now();
    state.pauseReason = 'manual';
    state.guardStatus = 'idle';
    state.guardStartedAt = undefined;
    state.guardReason = undefined;
    await StorageService.saveTimerState(state);
    await ReminderService.cancelCurrent();
    return state;
  }

  static async pauseForBackground(reason: FocusIntegrityViolationReason = 'left_app'): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (state.mode !== 'focus' || state.status === 'idle') {
      return state;
    }

    const now = Date.now();
    TimerService.markFocusIntegrityViolation(state, reason, now);
    await TimerService.abandonWithState(state, reason === 'app_terminated' ? 'other' : 'distracted', now);
    return StorageService.getTimerState();
  }

  private static async abandonWithState(
    state: TimerState,
    reason?: FocusAbandonReason,
    now: number = Date.now()
  ): Promise<FocusSession | null> {
    if (state.status === 'idle' || !state.startedAt || state.mode === 'break') {
      await TimerService.clearTimer();
      return null;
    }

    const pausedExtraMs = state.status === 'paused' && state.pausedAt ? now - state.pausedAt : 0;
    const actualDurationSeconds = Math.max(
      0,
      Math.floor((now - state.startedAt - state.accumulatedPausedMs - pausedExtraMs) / 1000)
    );
    const handoffNote = state.handoffNote && state.handoffNote.trim()
      ? state.handoffNote.trim()
      : createHandoffNote(state, reason);
    const session: FocusSession = {
      id: createId('session'),
      taskId: state.taskId,
      taskTitle: state.taskTitle,
      projectName: state.projectName,
      plannedDurationSeconds: state.durationSeconds,
      actualDurationSeconds,
      startedAt: state.startedAt,
      endedAt: now,
      status: 'abandoned',
      abandonReason: reason,
      awayCount: state.awayCount ? state.awayCount : 0,
      awaySeconds: (state.awaySeconds ? state.awaySeconds : 0)
        + (state.pauseReason === 'background'
          ? Math.floor(Math.max(0, now - (state.awayStartedAt !== undefined ? state.awayStartedAt : state.pausedAt ? state.pausedAt : now)) / 1000)
          : 0),
      microActionText: state.microActionText,
      microActionCompletedCount: state.microActionCompletedCount ? state.microActionCompletedCount : 0,
      microActionResetCount: state.microActionResetCount ? state.microActionResetCount : 0,
      handoffNote,
      focusGuardEnabled: state.focusGuardEnabled,
      focusWhitelistLabel: state.focusWhitelistLabel,
      focusIntegrityStatus: state.focusIntegrityStatus,
      focusIntegrityViolationReason: state.focusIntegrityViolationReason,
      focusIntegrityViolationCount: state.focusIntegrityViolationCount,
      focusIntegrityViolatedAt: state.focusIntegrityViolatedAt,
      returnProofRequiredCount: state.returnProofRequiredCount ? state.returnProofRequiredCount : 0,
      returnProofCompletedCount: state.returnProofCompletedCount ? state.returnProofCompletedCount : 0,
      returnProofSeconds: state.returnProofSeconds ? state.returnProofSeconds : 0,
      starterPlanRiskLevel: state.starterPlanRiskLevel,
      starterPlanReason: state.starterPlanReason,
      starterPlanDurationSeconds: state.starterPlanDurationSeconds,
      recoveryStepIndex: state.recoveryStepIndex,
      recoveryStepCount: state.recoveryStepCount,
      recoveryGateCleared: false,
      timeCoinsEarned: 0,
      timeCoinsDailyCap: TIME_COIN_DAILY_CAP,
      timeCoinsSessionCap: TIME_COIN_MAX_PER_SESSION,
      restartFromSessionId: state.restartFromSessionId,
      restartFromReason: state.restartFromReason,
      countsAsFocus: false
    };

    await SessionService.add(session);
    await TimerService.clearTimer();
    return session;
  }

  static async resume(): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (state.status !== 'paused' || !state.pausedAt || !state.expectedEndAt) {
      return state;
    }

    const now = Date.now();
    const wasBackgroundPause = state.pauseReason === 'background';
    const awayMs = TimerService.closeAwayPause(state, now);
    const pausedMs = now - state.pausedAt;
    state.status = 'running';
    state.expectedEndAt += pausedMs;
    if (state.microActionStartedAt) {
      state.microActionStartedAt += pausedMs;
    }
    if (state.returnProofStartedAt) {
      state.returnProofStartedAt += pausedMs;
    }
    state.accumulatedPausedMs += pausedMs;
    state.pausedAt = undefined;
    state.pauseReason = undefined;
    state.lastPresenceAt = now;
    state.guardStatus = 'idle';
    state.guardStartedAt = undefined;
    state.guardReason = undefined;
    if (wasBackgroundPause && Math.floor((awayMs ? awayMs : pausedMs) / 1000) >= RETURN_PROOF_TRIGGER_SECONDS) {
      TimerService.requireReturnProof(state, now);
    }

    await StorageService.saveTimerState(state);
    await ReminderService.scheduleForTimer(state);
    return state;
  }

  static async abandon(reason?: FocusAbandonReason): Promise<FocusSession | null> {
    const state = await StorageService.getTimerState();
    if (state.status === 'idle' || !state.startedAt) {
      return null;
    }

    if (state.mode === 'break') {
      await TimerService.clearTimer();
      return null;
    }

    return TimerService.abandonWithState(state, reason);
  }

  static async complete(): Promise<FocusSession | null> {
    const state = await StorageService.getTimerState();
    if (state.status !== 'running' || state.mode !== 'focus' || !state.startedAt || !state.expectedEndAt) {
      return null;
    }

    const normalizedState = await TimerService.pauseStalePresence(state);
    if (normalizedState.status !== 'running') {
      return null;
    }
    if (!normalizedState.expectedEndAt) {
      return null;
    }
    const now = Date.now();
    const didCompleteReturnProof = TimerService.normalizeReturnProof(normalizedState, now);
    if (TimerService.returnProofRemainingSeconds(normalizedState, now) > 0) {
      await StorageService.saveTimerState(normalizedState);
      await ReminderService.scheduleForTimer(normalizedState);
      return null;
    }
    if (TimerService.hasFocusIntegrityViolation(normalizedState)) {
      await StorageService.saveTimerState(normalizedState);
      await ReminderService.scheduleForTimer(normalizedState);
      return null;
    }
    if (didCompleteReturnProof) {
      await StorageService.saveTimerState(normalizedState);
    }

    return TimerService.completeFocusState(normalizedState, normalizedState.expectedEndAt, normalizedState.durationSeconds);
  }

  static async completeEarly(minimumSeconds: number): Promise<FocusSession | null> {
    const state = await StorageService.getTimerState();
    if (state.status === 'idle' || state.mode !== 'focus' || !state.startedAt) {
      return null;
    }

    const ignoredMinimumSeconds = minimumSeconds;
    if (ignoredMinimumSeconds < 1) {
      return null;
    }

    await TimerService.pauseStalePresence(state);
    return null;
  }

  private static async completeFocusState(
    state: TimerState,
    endedAt: number,
    actualDurationSeconds: number
  ): Promise<FocusSession> {
    const startedAt = state.startedAt ? state.startedAt : endedAt;
    const existingSessions = await SessionService.listAll();
    const canEarnTimeCoins = state.restartFromReason !== 'abandoned_retry'
      && state.focusIntegrityStatus !== 'violated';
    const timeCoinsEarned = canEarnTimeCoins
      ? awardTimeCoins(existingSessions, actualDurationSeconds, endedAt)
      : 0;
    const session: FocusSession = {
      id: createId('session'),
      taskId: state.taskId,
      taskTitle: state.taskTitle,
      projectName: state.projectName,
      plannedDurationSeconds: state.durationSeconds,
      actualDurationSeconds,
      startedAt,
      endedAt,
      status: 'completed',
      awayCount: state.awayCount ? state.awayCount : 0,
      awaySeconds: state.awaySeconds ? state.awaySeconds : 0,
      microActionText: state.microActionText,
      microActionCompletedCount: state.microActionCompletedCount ? state.microActionCompletedCount : 0,
      microActionResetCount: state.microActionResetCount ? state.microActionResetCount : 0,
      focusGuardEnabled: state.focusGuardEnabled,
      focusWhitelistLabel: state.focusWhitelistLabel,
      focusIntegrityStatus: state.focusIntegrityStatus,
      focusIntegrityViolationReason: state.focusIntegrityViolationReason,
      focusIntegrityViolationCount: state.focusIntegrityViolationCount,
      focusIntegrityViolatedAt: state.focusIntegrityViolatedAt,
      returnProofRequiredCount: state.returnProofRequiredCount ? state.returnProofRequiredCount : 0,
      returnProofCompletedCount: state.returnProofCompletedCount ? state.returnProofCompletedCount : 0,
      returnProofSeconds: state.returnProofSeconds ? state.returnProofSeconds : 0,
      starterPlanRiskLevel: state.starterPlanRiskLevel,
      starterPlanReason: state.starterPlanReason,
      starterPlanDurationSeconds: state.starterPlanDurationSeconds,
      recoveryStepIndex: state.recoveryStepIndex,
      recoveryStepCount: state.recoveryStepCount,
      recoveryGateCleared: state.restartFromReason === 'abandoned_retry'
        && state.recoveryStepIndex !== undefined
        && state.recoveryStepIndex >= (state.recoveryStepCount ? state.recoveryStepCount : RECOVERY_GATE_STEP_SECONDS.length) - 1,
      timeCoinsEarned,
      timeCoinsDailyCap: TIME_COIN_DAILY_CAP,
      timeCoinsSessionCap: TIME_COIN_MAX_PER_SESSION,
      restartFromSessionId: state.restartFromSessionId,
      restartFromReason: state.restartFromReason,
      countsAsFocus: state.restartFromReason === 'abandoned_retry' ? false : true
    };

    await SessionService.add(session);
    if (state.restartFromReason !== 'abandoned_retry') {
      await TaskService.incrementCompletedFocusCount(state.taskId);
    }
    await ReminderService.cancelCurrent();
    await NotificationService.notifyFocusCompleted(Math.round(actualDurationSeconds / 60));
    const completedRounds = state.restartFromReason === 'abandoned_retry'
      ? await PomodoroProgressService.getCompletedFocusRounds()
      : await PomodoroProgressService.incrementFocusRounds();
    await TimerService.prepareBreak(completedRounds);
    return session;
  }

  static async completeBreak(): Promise<void> {
    await ReminderService.cancelCurrent();
    await NotificationService.notifyBreakCompleted();
    await TimerService.clearTimer();
  }

  static async restore(): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (!state) {
      return cloneIdleState();
    }

    if (state.status === 'idle') {
      return state;
    }

    if (state.status === 'running' && state.expectedEndAt) {
      const normalizedState = await TimerService.pauseStalePresence(state);
      if (normalizedState.status !== 'running') {
        return normalizedState;
      }

      const remainingMs = state.expectedEndAt - Date.now();
      if (remainingMs <= 0) {
        if (state.mode === 'break') {
          await TimerService.completeBreak();
          return cloneIdleState();
        } else {
          await TimerService.complete();
          return StorageService.getTimerState();
        }
      }
    }

    return state;
  }

  private static async pauseStalePresence(state: TimerState): Promise<TimerState> {
    if (state.mode !== 'focus' || state.status !== 'running' || !state.startedAt || !state.expectedEndAt) {
      return state;
    }

    const lastPresenceAt = state.lastPresenceAt ? state.lastPresenceAt : state.startedAt;
    if (Date.now() - lastPresenceAt <= PRESENCE_GRACE_MS) {
      return state;
    }

    TimerService.registerAwayPause(state, Math.min(lastPresenceAt, state.expectedEndAt), 'stale_presence');
    await TimerService.abandonWithState(state, 'distracted');
    return StorageService.getTimerState();
  }

  static async getRemainingSeconds(): Promise<number> {
    const state = await StorageService.getTimerState();
    if (state.status === 'idle') {
      return state.mode === 'break' ? state.durationSeconds : 0;
    }

    if (state.status === 'paused' && state.pausedAt && state.expectedEndAt) {
      return Math.max(0, Math.ceil((state.expectedEndAt - state.pausedAt) / 1000));
    }

    if (state.expectedEndAt) {
      return Math.max(0, Math.ceil((state.expectedEndAt - Date.now()) / 1000));
    }

    return idleTimerState.durationSeconds;
  }

  static async clearTimer(): Promise<void> {
    await ReminderService.cancelCurrent();
    await StorageService.clearTimerState();
  }

  private static async prepareBreak(completedRounds: number): Promise<void> {
    const config = await StorageService.getConfig();
    const shouldUseLongBreak = completedRounds % config.roundsBeforeLongBreak === 0;
    const breakMinutes = shouldUseLongBreak ? config.longBreakMinutes : config.shortBreakMinutes;
    const breakTitle = shouldUseLongBreak ? '长歇息' : '歇息';
    const state: TimerState = {
      id: '',
      mode: 'break',
      status: 'idle',
      taskTitle: breakTitle,
      durationSeconds: breakMinutes * 60,
      accumulatedPausedMs: 0
    };

    await StorageService.saveTimerState(state);
  }
}
