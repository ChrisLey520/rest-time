import assert from 'node:assert/strict';
import {
  TIME_COIN_DAILY_CAP,
  TIME_COIN_MAX_PER_SESSION,
  awardTimeCoins
} from './helpers/timeCoinCore.mjs';

const FOCUS_GUARD_COOLDOWN_SECONDS = 20;
const MICRO_ACTION_SECONDS = 3 * 60;
const RETURN_PROOF_SECONDS = 60;
const RETURN_PROOF_TRIGGER_SECONDS = 15;
const RECOVERY_GATE_STEP_SECONDS = [60, 3 * 60, 5 * 60];

function createMemoryStorage() {
  return {
    timerState: {
      id: '',
      mode: 'focus',
      status: 'idle',
      durationSeconds: 0,
      accumulatedPausedMs: 0
    },
    sessions: [],
    tasks: [],
    progress: {
      completedFocusRounds: 0
    },
    config: {
      shortBreakMinutes: 5,
      longBreakMinutes: 15,
      roundsBeforeLongBreak: 4,
      focusGuardEnabled: true
    }
  };
}

function createTimerCore(storage, nowRef) {
  const idle = () => ({
    id: '',
    mode: 'focus',
    status: 'idle',
    durationSeconds: 0,
    accumulatedPausedMs: 0
  });

  const inferRecoveryStepIndex = (actualDurationSeconds) => {
    for (let index = 0; index < RECOVERY_GATE_STEP_SECONDS.length; index += 1) {
      if (actualDurationSeconds <= RECOVERY_GATE_STEP_SECONDS[index]) {
        return index;
      }
    }

    return RECOVERY_GATE_STEP_SECONDS.length - 1;
  };

  const nextRecoveryStepIndexForSession = (session) => {
    if (!session) return -1;
    if (session.status === 'abandoned') return 0;
    if (session.status === 'completed' && session.restartFromReason === 'abandoned_retry') {
      const stepIndex = session.recoveryStepIndex !== undefined
        ? session.recoveryStepIndex
        : inferRecoveryStepIndex(session.actualDurationSeconds);
      return stepIndex + 1;
    }

    return -1;
  };

  const recoveryDurationSecondsForStepIndex = (stepIndex) => {
    if (stepIndex < 0) return RECOVERY_GATE_STEP_SECONDS[RECOVERY_GATE_STEP_SECONDS.length - 1];
    if (stepIndex >= RECOVERY_GATE_STEP_SECONDS.length) return RECOVERY_GATE_STEP_SECONDS[RECOVERY_GATE_STEP_SECONDS.length - 1];
    return RECOVERY_GATE_STEP_SECONDS[stepIndex];
  };

  const getRecoveryGate = () => {
    const session = storage.sessions.length > 0 ? storage.sessions[0] : undefined;
    const stepIndex = nextRecoveryStepIndexForSession(session);
    const isRequired = stepIndex >= 0 && stepIndex < RECOVERY_GATE_STEP_SECONDS.length;
    return {
      isRequired,
      session,
      nextStepIndex: isRequired ? stepIndex : -1,
      nextDurationSeconds: isRequired ? recoveryDurationSecondsForStepIndex(stepIndex) : 0
    };
  };

  const finishFocus = (state, endedAt, actualDurationSeconds) => {
    const canEarnTimeCoins = state.restartFromReason !== 'abandoned_retry'
      && state.focusIntegrityStatus !== 'violated';
    const timeCoinsEarned = canEarnTimeCoins
      ? awardTimeCoins(storage.sessions, actualDurationSeconds, endedAt)
      : 0;
    const session = {
      id: `session_${nowRef.now}`,
      taskId: state.taskId,
      taskTitle: state.taskTitle,
      projectName: state.projectName,
      plannedDurationSeconds: state.durationSeconds,
      actualDurationSeconds,
      startedAt: state.startedAt,
      endedAt,
      status: 'completed',
      awayCount: state.awayCount || 0,
      awaySeconds: state.awaySeconds || 0,
      microActionText: state.microActionText,
      microActionCompletedCount: state.microActionCompletedCount || 0,
      microActionResetCount: state.microActionResetCount || 0,
      handoffNote: state.handoffNote,
      focusGuardEnabled: state.focusGuardEnabled,
      focusWhitelistLabel: state.focusWhitelistLabel,
      focusIntegrityStatus: state.focusIntegrityStatus,
      focusIntegrityViolationReason: state.focusIntegrityViolationReason,
      focusIntegrityViolationCount: state.focusIntegrityViolationCount,
      focusIntegrityViolatedAt: state.focusIntegrityViolatedAt,
      returnProofRequiredCount: state.returnProofRequiredCount || 0,
      returnProofCompletedCount: state.returnProofCompletedCount || 0,
      returnProofSeconds: state.returnProofSeconds || 0,
      starterPlanRiskLevel: state.starterPlanRiskLevel,
      starterPlanReason: state.starterPlanReason,
      starterPlanDurationSeconds: state.starterPlanDurationSeconds,
      recoveryStepIndex: state.recoveryStepIndex,
      recoveryStepCount: state.recoveryStepCount,
      recoveryGateCleared: state.restartFromReason === 'abandoned_retry'
        && state.recoveryStepIndex !== undefined
        && state.recoveryStepIndex >= (state.recoveryStepCount || RECOVERY_GATE_STEP_SECONDS.length) - 1,
      timeCoinsEarned,
      timeCoinsDailyCap: TIME_COIN_DAILY_CAP,
      timeCoinsSessionCap: TIME_COIN_MAX_PER_SESSION,
      restartFromSessionId: state.restartFromSessionId,
      restartFromReason: state.restartFromReason,
      countsAsFocus: state.restartFromReason === 'abandoned_retry' ? false : true
    };
    storage.sessions.unshift(session);
    const task = storage.tasks.find((item) => item.id === state.taskId);
    if (task && state.restartFromReason !== 'abandoned_retry') {
      task.completedFocusCount += 1;
    }
    if (state.restartFromReason !== 'abandoned_retry') {
      storage.progress.completedFocusRounds += 1;
    }
    const shouldUseLongBreak = storage.progress.completedFocusRounds % storage.config.roundsBeforeLongBreak === 0;
    storage.timerState = {
      id: '',
      mode: 'break',
      status: 'idle',
      taskTitle: shouldUseLongBreak ? '长歇息' : '歇息',
      durationSeconds: (shouldUseLongBreak ? storage.config.longBreakMinutes : storage.config.shortBreakMinutes) * 60,
      accumulatedPausedMs: 0
    };
    return session;
  };

  return {
    hasFocusIntegrityViolation(state = storage.timerState) {
      return state.focusIntegrityStatus === 'violated';
    },

    nextRecoveryStepIndex(session) {
      return nextRecoveryStepIndexForSession(session);
    },

    recoveryDurationSecondsForStep(stepIndex) {
      return recoveryDurationSecondsForStepIndex(stepIndex);
    },

    getRecoveryGate() {
      return getRecoveryGate();
    },

    markFocusIntegrityViolation(state, reason) {
      state.focusGuardEnabled = true;
      state.focusWhitelistLabel = state.focusWhitelistLabel || '栖时前台';
      state.focusIntegrityStatus = 'violated';
      state.focusIntegrityViolationReason = reason;
      state.focusIntegrityViolationCount = (state.focusIntegrityViolationCount || 0) + 1;
      state.focusIntegrityViolatedAt = nowRef.now;
      state.handoffNote = state.handoffNote || `下次从这里继续：${state.microActionText || '当前任务'}`;
      return state;
    },

    isFocusStartBlocked() {
      const state = storage.timerState;
      return state.status === 'running' || state.status === 'paused' || state.mode === 'break';
    },

    tryStartFocus(
      durationSeconds = 60,
      taskId = 'task_1',
      taskTitle = '自由专注',
      projectName = undefined,
      restartFromSessionId = undefined,
      starterPlanRiskLevel = undefined,
      starterPlanReason = undefined,
      recoveryStepIndex = undefined,
      recoveryStepCount = undefined
    ) {
      if (this.isFocusStartBlocked()) {
        return {
          didStart: false,
          state: storage.timerState,
          message: 'blocked'
        };
      }

      const recoveryGate = getRecoveryGate();
      if (recoveryGate.isRequired && !restartFromSessionId) {
        return {
          didStart: false,
          state: storage.timerState,
          message: `先完成 ${Math.max(1, Math.floor(recoveryGate.nextDurationSeconds / 60))} 分钟恢复，再回到正常专注`,
          recoveryRequiredSessionId: recoveryGate.session ? recoveryGate.session.id : undefined
        };
      }

      let nextDurationSeconds = durationSeconds;
      let nextRecoveryStepIndex = recoveryStepIndex;
      let nextRecoveryStepCount = recoveryStepCount;
      if (recoveryGate.isRequired) {
        nextDurationSeconds = recoveryGate.nextDurationSeconds;
        nextRecoveryStepIndex = recoveryGate.nextStepIndex;
        nextRecoveryStepCount = RECOVERY_GATE_STEP_SECONDS.length;
      }

      return {
        didStart: true,
        state: this.startFocus(
          nextDurationSeconds,
          taskId,
          taskTitle,
          projectName,
          restartFromSessionId,
          starterPlanRiskLevel,
          starterPlanReason,
          nextRecoveryStepIndex,
          nextRecoveryStepCount
        ),
        message: ''
      };
    },

    startFocus(
      durationSeconds = 60,
      taskId = 'task_1',
      taskTitle = '自由专注',
      projectName = undefined,
      restartFromSessionId = undefined,
      starterPlanRiskLevel = undefined,
      starterPlanReason = undefined,
      recoveryStepIndex = undefined,
      recoveryStepCount = undefined
    ) {
      if (this.isFocusStartBlocked()) {
        return storage.timerState;
      }

      const recoveryGate = getRecoveryGate();
      if (recoveryGate.isRequired) {
        if (!restartFromSessionId) {
          return storage.timerState;
        }

        durationSeconds = recoveryGate.nextDurationSeconds;
        recoveryStepIndex = recoveryGate.nextStepIndex;
        recoveryStepCount = RECOVERY_GATE_STEP_SECONDS.length;
      }

      const now = nowRef.now;
      storage.timerState = {
        id: `timer_${now}`,
        mode: 'focus',
        status: 'running',
        taskId,
        taskTitle,
        projectName,
        startedAt: now,
        lastPresenceAt: now,
        guardStatus: 'idle',
        microActionText: taskTitle === '自由专注' ? '先写下这 3 分钟要推进的一小步' : `先推进「${taskTitle}」最小的一步`,
        microActionStartedAt: now,
        microActionDurationSeconds: MICRO_ACTION_SECONDS,
        microActionCompletedCount: 0,
        microActionResetCount: 0,
        focusGuardEnabled: true,
        focusWhitelistLabel: '栖时前台',
        focusIntegrityStatus: 'clean',
        starterPlanRiskLevel,
        starterPlanReason,
        starterPlanDurationSeconds: durationSeconds,
        recoveryStepIndex,
        recoveryStepCount,
        restartFromSessionId,
        restartFromReason: restartFromSessionId ? 'abandoned_retry' : undefined,
        expectedEndAt: now + durationSeconds * 1000,
        durationSeconds,
        accumulatedPausedMs: 0
      };
      return storage.timerState;
    },

    startBreak(durationSeconds) {
      const currentState = storage.timerState;
      if (currentState.status !== 'idle') {
        return currentState;
      }

      const plannedDurationSeconds = durationSeconds
        ? durationSeconds
        : currentState.mode === 'break' && currentState.durationSeconds > 0
          ? currentState.durationSeconds
          : storage.config.shortBreakMinutes * 60;
      storage.timerState = {
        id: `timer_${nowRef.now}`,
        mode: 'break',
        status: 'running',
        taskTitle: currentState.mode === 'break' && currentState.taskTitle ? currentState.taskTitle : '歇息',
        startedAt: nowRef.now,
        expectedEndAt: nowRef.now + plannedDurationSeconds * 1000,
        durationSeconds: plannedDurationSeconds,
        accumulatedPausedMs: 0
      };
      return storage.timerState;
    },

    startAbandonGuard(reason) {
      const state = storage.timerState;
      if (state.status === 'idle' || state.mode !== 'focus' || !state.startedAt) return state;
      state.guardStatus = 'cooling';
      state.guardStartedAt = nowRef.now;
      state.guardReason = reason;
      state.handoffNote = `下次先回到这一小步：${state.microActionText || '当前任务'}`;
      return state;
    },

    cancelAbandonGuard() {
      const state = storage.timerState;
      if (state.guardStatus === 'cooling') {
        state.guardStatus = 'idle';
        state.guardStartedAt = undefined;
        state.guardReason = undefined;
      }
      return state;
    },

    abandonGuardRemainingSeconds(state = storage.timerState) {
      if (state.guardStatus !== 'cooling' || !state.guardStartedAt) return 0;
      const elapsedSeconds = Math.floor((nowRef.now - state.guardStartedAt) / 1000);
      return Math.max(0, FOCUS_GUARD_COOLDOWN_SECONDS - elapsedSeconds);
    },

    microActionRemainingSeconds(state = storage.timerState) {
      if (!state.microActionStartedAt || !state.microActionDurationSeconds) return 0;
      const effectiveNow = state.status === 'paused' && state.pausedAt ? state.pausedAt : nowRef.now;
      const elapsedSeconds = Math.floor((effectiveNow - state.microActionStartedAt) / 1000);
      return Math.max(0, state.microActionDurationSeconds - elapsedSeconds);
    },

    completeMicroAction() {
      const state = storage.timerState;
      if (state.status === 'idle' || state.mode !== 'focus') return state;
      state.microActionCompletedCount = (state.microActionCompletedCount || 0) + 1;
      state.microActionText = `只做 3 分钟：${state.microActionText || '当前任务'}`;
      state.microActionStartedAt = nowRef.now;
      state.microActionDurationSeconds = MICRO_ACTION_SECONDS;
      return state;
    },

    resetMicroAction(text) {
      const state = storage.timerState;
      if (state.status === 'idle' || state.mode !== 'focus') return state;
      state.microActionResetCount = (state.microActionResetCount || 0) + 1;
      state.microActionText = text || `只做 3 分钟：${state.taskTitle || state.microActionText || '当前任务'}`;
      state.microActionStartedAt = nowRef.now;
      state.microActionDurationSeconds = MICRO_ACTION_SECONDS;
      return state;
    },

    registerAwayPause(state, pausedAt, reason = 'left_app', awayStartedAt = undefined) {
      state.status = 'paused';
      state.pausedAt = pausedAt;
      state.pauseReason = 'background';
      state.awayStartedAt = awayStartedAt !== undefined ? awayStartedAt : pausedAt;
      state.awayCount = (state.awayCount || 0) + 1;
      state.guardStatus = 'idle';
      state.guardStartedAt = undefined;
      state.guardReason = undefined;
      this.markFocusIntegrityViolation(state, reason);
      return state;
    },

    closeAwayPause(state) {
      if (state.pauseReason !== 'background') return 0;
      const awayStartedAt = state.awayStartedAt !== undefined ? state.awayStartedAt : state.pausedAt;
      if (awayStartedAt === undefined) return 0;
      const awayMs = Math.max(0, nowRef.now - awayStartedAt);
      state.awaySeconds = (state.awaySeconds || 0) + Math.floor(awayMs / 1000);
      state.awayStartedAt = undefined;
      return awayMs;
    },

    requireReturnProof(state) {
      state.returnProofRequiredCount = (state.returnProofRequiredCount || 0) + 1;
      state.returnProofStartedAt = nowRef.now;
      state.returnProofDurationSeconds = RETURN_PROOF_SECONDS;
      if (state.expectedEndAt) {
        const proofReadyAt = nowRef.now + RETURN_PROOF_SECONDS * 1000;
        if (state.expectedEndAt < proofReadyAt) {
          state.expectedEndAt = proofReadyAt;
        }
      }
      return state;
    },

    normalizeReturnProof(state) {
      if (!state.returnProofStartedAt || !state.returnProofDurationSeconds) return false;
      const elapsedSeconds = Math.floor((nowRef.now - state.returnProofStartedAt) / 1000);
      if (elapsedSeconds < state.returnProofDurationSeconds) return false;
      state.returnProofCompletedCount = (state.returnProofCompletedCount || 0) + 1;
      state.returnProofSeconds = (state.returnProofSeconds || 0) + state.returnProofDurationSeconds;
      state.returnProofStartedAt = undefined;
      state.returnProofDurationSeconds = undefined;
      return true;
    },

    returnProofRemainingSeconds(state = storage.timerState) {
      if (!state.returnProofStartedAt || !state.returnProofDurationSeconds) return 0;
      const effectiveNow = state.status === 'paused' && state.pausedAt ? state.pausedAt : nowRef.now;
      const elapsedSeconds = Math.floor((effectiveNow - state.returnProofStartedAt) / 1000);
      return Math.max(0, state.returnProofDurationSeconds - elapsedSeconds);
    },

    awaySeconds(state = storage.timerState) {
      const savedAwaySeconds = state.awaySeconds || 0;
      if (state.pauseReason !== 'background') return savedAwaySeconds;
      const awayStartedAt = state.awayStartedAt !== undefined ? state.awayStartedAt : state.pausedAt;
      if (awayStartedAt === undefined) return savedAwaySeconds;
      return savedAwaySeconds + Math.floor(Math.max(0, nowRef.now - awayStartedAt) / 1000);
    },

    markPresence() {
      const state = storage.timerState;
      if (state.status === 'running' && state.mode === 'focus') {
        const lastPresenceAt = state.lastPresenceAt || state.startedAt;
        if (nowRef.now - lastPresenceAt > 5000) {
          this.registerAwayPause(state, Math.min(lastPresenceAt, state.expectedEndAt), 'stale_presence');
          this.abandon('distracted');
          return storage.timerState;
        }

        this.normalizeReturnProof(state);
        if (nowRef.now - lastPresenceAt >= 2000) {
          state.lastPresenceAt = nowRef.now;
        }
      }
      return state;
    },

    shrinkCurrentFocusRemaining(remainingSeconds) {
      const state = storage.timerState;
      if (state.status === 'idle' || state.mode !== 'focus' || !state.startedAt || !state.expectedEndAt) return state;
      if (state.mode === 'focus') return state;
      if (state.status === 'paused' && state.pausedAt) {
        const wasBackgroundPause = state.pauseReason === 'background';
        const awayMs = this.closeAwayPause(state);
        const pausedMs = nowRef.now - state.pausedAt;
        state.accumulatedPausedMs += pausedMs;
        state.pausedAt = undefined;
        state.pauseReason = undefined;
        state.status = 'running';
        state.lastPresenceAt = nowRef.now;
        if (state.microActionStartedAt) {
          state.microActionStartedAt += pausedMs;
        }
        if (state.returnProofStartedAt) {
          state.returnProofStartedAt += pausedMs;
        }
        if (state.expectedEndAt) {
          state.expectedEndAt += pausedMs;
        }
        if (wasBackgroundPause && Math.floor((awayMs || pausedMs) / 1000) >= RETURN_PROOF_TRIGGER_SECONDS) {
          this.requireReturnProof(state);
        }
      }

      const currentRemainingSeconds = Math.max(0, Math.ceil((state.expectedEndAt - nowRef.now) / 1000));
      const safeRemainingSeconds = Math.max(1, Math.floor(remainingSeconds));
      if (currentRemainingSeconds > safeRemainingSeconds) {
        const elapsedSeconds = Math.max(0, Math.floor((nowRef.now - state.startedAt - state.accumulatedPausedMs) / 1000));
        state.durationSeconds = elapsedSeconds + safeRemainingSeconds;
        state.expectedEndAt = nowRef.now + safeRemainingSeconds * 1000;
      }
      return state;
    },

    pause() {
      const state = storage.timerState;
      if (state.status !== 'running') return state;
      if (state.mode === 'focus') return state;
      state.status = 'paused';
      state.pausedAt = nowRef.now;
      state.pauseReason = 'manual';
      state.guardStatus = 'idle';
      state.guardStartedAt = undefined;
      state.guardReason = undefined;
      return state;
    },

    pauseForBackground(reason = 'left_app') {
      const state = storage.timerState;
      if (state.mode !== 'focus' || state.status === 'idle') return state;
      this.markFocusIntegrityViolation(state, reason);
      this.abandon(reason === 'app_terminated' ? 'other' : 'distracted');
      return storage.timerState;
    },

    resume() {
      const state = storage.timerState;
      if (state.status !== 'paused' || !state.pausedAt || !state.expectedEndAt) return state;
      const wasBackgroundPause = state.pauseReason === 'background';
      const awayMs = this.closeAwayPause(state);
      const pausedMs = nowRef.now - state.pausedAt;
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
      state.lastPresenceAt = nowRef.now;
      state.guardStatus = 'idle';
      state.guardStartedAt = undefined;
      state.guardReason = undefined;
      if (wasBackgroundPause && Math.floor((awayMs || pausedMs) / 1000) >= RETURN_PROOF_TRIGGER_SECONDS) {
        this.requireReturnProof(state);
      }
      return state;
    },

    complete() {
      const state = storage.timerState;
      if (state.status !== 'running' || state.mode !== 'focus' || !state.startedAt || !state.expectedEndAt) return null;
      const lastPresenceAt = state.lastPresenceAt || state.startedAt;
      if (nowRef.now - lastPresenceAt > 5000) {
        this.registerAwayPause(state, Math.min(lastPresenceAt, state.expectedEndAt), 'stale_presence');
        this.abandon('distracted');
        return null;
      }
      this.normalizeReturnProof(state);
      if (this.returnProofRemainingSeconds(state) > 0) return null;
      if (this.hasFocusIntegrityViolation(state)) return null;
      return finishFocus(state, state.expectedEndAt, state.durationSeconds);
    },

    completeEarly(minimumSeconds) {
      const state = storage.timerState;
      if (state.status === 'idle' || state.mode !== 'focus' || !state.startedAt) return null;
      if (state.status === 'running') {
        const lastPresenceAt = state.lastPresenceAt || state.startedAt;
        if (nowRef.now - lastPresenceAt > 5000) {
          this.registerAwayPause(state, Math.min(lastPresenceAt, state.expectedEndAt), 'stale_presence');
          this.abandon('distracted');
        }
      }
      return null;
    },

    abandon(reason) {
      const state = storage.timerState;
      if (state.status === 'idle' || !state.startedAt) return null;
      const pausedExtraMs = state.status === 'paused' && state.pausedAt ? nowRef.now - state.pausedAt : 0;
      const actualDurationSeconds = Math.max(
        0,
        Math.floor((nowRef.now - state.startedAt - state.accumulatedPausedMs - pausedExtraMs) / 1000)
      );
      const session = {
        id: `session_${nowRef.now}`,
        taskId: state.taskId,
        taskTitle: state.taskTitle,
        projectName: state.projectName,
        plannedDurationSeconds: state.durationSeconds,
        actualDurationSeconds,
        startedAt: state.startedAt,
        endedAt: nowRef.now,
        status: 'abandoned',
        abandonReason: reason,
        awayCount: state.awayCount || 0,
        awaySeconds: (state.awaySeconds || 0) + (state.pauseReason === 'background'
          ? Math.floor(Math.max(0, nowRef.now - (state.awayStartedAt !== undefined ? state.awayStartedAt : state.pausedAt || nowRef.now)) / 1000)
          : 0),
        microActionText: state.microActionText,
        microActionCompletedCount: state.microActionCompletedCount || 0,
        microActionResetCount: state.microActionResetCount || 0,
        handoffNote: state.handoffNote || `下次从这里继续：${state.microActionText || '当前任务'}`,
        focusGuardEnabled: state.focusGuardEnabled,
        focusWhitelistLabel: state.focusWhitelistLabel,
        focusIntegrityStatus: state.focusIntegrityStatus,
        focusIntegrityViolationReason: state.focusIntegrityViolationReason,
        focusIntegrityViolationCount: state.focusIntegrityViolationCount,
        focusIntegrityViolatedAt: state.focusIntegrityViolatedAt,
        returnProofRequiredCount: state.returnProofRequiredCount || 0,
        returnProofCompletedCount: state.returnProofCompletedCount || 0,
        returnProofSeconds: state.returnProofSeconds || 0,
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
      storage.sessions.unshift(session);
      storage.timerState = idle();
      return session;
    },

    restore() {
      const state = storage.timerState;
      if (state.status === 'idle') return state;
      if (state.status === 'running' && state.expectedEndAt <= nowRef.now) {
        const lastPresenceAt = state.lastPresenceAt || state.startedAt;
        if (state.mode === 'focus' && nowRef.now - lastPresenceAt > 5000) {
          this.registerAwayPause(state, Math.min(lastPresenceAt, state.expectedEndAt), 'stale_presence');
          this.abandon('distracted');
          return storage.timerState;
        }

        if (state.mode === 'break') {
          storage.timerState = idle();
        } else {
          this.complete();
        }
        return storage.timerState;
      }
      if (state.status === 'running' && state.mode === 'focus') {
        const lastPresenceAt = state.lastPresenceAt || state.startedAt;
        if (nowRef.now - lastPresenceAt > 5000) {
          this.registerAwayPause(state, Math.min(lastPresenceAt, state.expectedEndAt), 'stale_presence');
          this.abandon('distracted');
          return storage.timerState;
        }
      }
      return state;
    },

    getRemainingSeconds() {
      const state = storage.timerState;
      if (state.status === 'idle') return state.mode === 'break' ? state.durationSeconds : 0;
      if (state.status === 'paused' && state.pausedAt && state.expectedEndAt) {
        return Math.max(0, Math.ceil((state.expectedEndAt - state.pausedAt) / 1000));
      }
      return Math.max(0, Math.ceil((state.expectedEndAt - nowRef.now) / 1000));
    }
  };
}

function advancePresent(nowRef, timer, milliseconds) {
  const target = nowRef.now + milliseconds;
  while (nowRef.now < target) {
    nowRef.now = Math.min(target, nowRef.now + 1000);
    timer.markPresence();
  }
}

{
  const storage = createMemoryStorage();
  const nowRef = { now: 900_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(300, 'task_1', '写方案', '工作');
  advancePresent(nowRef, timer, 30_000);
  const guardedState = timer.startAbandonGuard('blocked');

  assert.equal(guardedState.guardStatus, 'cooling');
  assert.equal(guardedState.guardReason, 'blocked');
  assert.equal(timer.abandonGuardRemainingSeconds(), 20);
  assert.equal(storage.sessions.length, 0);

  nowRef.now += 10_000;
  assert.equal(timer.abandonGuardRemainingSeconds(), 10);
  timer.cancelAbandonGuard();
  assert.equal(storage.timerState.guardStatus, 'idle');
  assert.equal(storage.timerState.guardReason, undefined);
  assert.equal(storage.timerState.status, 'running');
  assert.equal(storage.sessions.length, 0);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '自由专注',
    estimatedFocusCount: 2,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 1_000_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(60, 'task_1', '自由专注', '工作');
  assert.equal(timer.getRemainingSeconds(), 60);
  assert.equal(storage.timerState.microActionText, '先写下这 3 分钟要推进的一小步');
  assert.equal(timer.microActionRemainingSeconds(), 180);

  advancePresent(nowRef, timer, 10_000);
  assert.equal(timer.getRemainingSeconds(), 50);
  assert.equal(timer.microActionRemainingSeconds(), 170);

  timer.pause();
  assert.equal(storage.timerState.pauseReason, undefined);
  assert.equal(storage.timerState.status, 'running');
  nowRef.now += 1_000;
  timer.markPresence();
  assert.equal(storage.timerState.status, 'running');
  assert.equal(storage.timerState.pauseReason, undefined);
  assert.equal(storage.sessions.length, 0);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '自由专注',
    estimatedFocusCount: 2,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 1_100_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(60, 'task_1', '自由专注', '工作');
  advancePresent(nowRef, timer, 60_000);
  timer.restore();
  assert.equal(storage.timerState.status, 'idle');
  assert.equal(storage.timerState.mode, 'break');
  assert.equal(storage.timerState.taskTitle, '歇息');
  assert.equal(timer.getRemainingSeconds(), 300);
  assert.equal(storage.sessions.length, 1);
  assert.equal(storage.sessions[0].status, 'completed');
  assert.equal(storage.sessions[0].projectName, '工作');
  assert.equal(storage.sessions[0].actualDurationSeconds, 60);
  assert.equal(storage.sessions[0].microActionCompletedCount, 0);
  assert.equal(storage.tasks[0].completedFocusCount, 1);
  assert.equal(storage.progress.completedFocusRounds, 1);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '写方案',
    estimatedFocusCount: 1,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 1_500_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(240, 'task_1', '写方案', '工作');
  assert.equal(storage.timerState.microActionText, '先推进「写方案」最小的一步');
  advancePresent(nowRef, timer, 30_000);
  timer.completeMicroAction();
  assert.equal(storage.timerState.microActionCompletedCount, 1);
  assert.equal(timer.microActionRemainingSeconds(), 180);
  timer.resetMicroAction();
  assert.equal(storage.timerState.microActionResetCount, 1);
  assert.match(storage.timerState.microActionText, /只做 3 分钟/);
  advancePresent(nowRef, timer, 210_000);
  timer.restore();

  assert.equal(storage.sessions.length, 1);
  assert.equal(storage.sessions[0].status, 'completed');
  assert.equal(storage.sessions[0].microActionCompletedCount, 1);
  assert.equal(storage.sessions[0].microActionResetCount, 1);
  assert.match(storage.sessions[0].microActionText, /只做 3 分钟/);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '自由专注',
    estimatedFocusCount: 2,
    completedFocusCount: 0,
    status: 'active'
  });
  storage.tasks.push({
    id: 'task_2',
    title: '写方案',
    estimatedFocusCount: 1,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 2_000_000 };
  const timer = createTimerCore(storage, nowRef);

  const firstResult = timer.tryStartFocus(60, 'task_1', '自由专注');
  nowRef.now += 5_000;
  const secondResult = timer.tryStartFocus(120, 'task_2', '写方案');

  assert.equal(firstResult.didStart, true);
  assert.equal(secondResult.didStart, false);
  assert.equal(storage.timerState.taskId, 'task_1');
  assert.equal(storage.timerState.taskTitle, '自由专注');
  assert.equal(storage.timerState.durationSeconds, 60);
  assert.equal(timer.getRemainingSeconds(), 55);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '自由专注',
    estimatedFocusCount: 2,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 5_000_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(60, 'task_1', '自由专注', '个人');
  nowRef.now += 12_200;
  const session = timer.abandon();

  assert.equal(session.status, 'abandoned');
  assert.equal(session.projectName, '个人');
  assert.equal(session.actualDurationSeconds, 12);
  assert.equal(storage.timerState.status, 'idle');
  assert.equal(storage.tasks[0].completedFocusCount, 0);
  assert.equal(storage.progress.completedFocusRounds, 0);
}

{
  const storage = createMemoryStorage();
  const nowRef = { now: 8_000_000 };
  const timer = createTimerCore(storage, nowRef);

  for (let i = 0; i < 4; i += 1) {
    timer.startFocus(60);
    advancePresent(nowRef, timer, 60_000);
    timer.restore();
    if (i < 3) {
      assert.equal(storage.timerState.taskTitle, '歇息');
      storage.timerState = {
        id: '',
        mode: 'focus',
        status: 'idle',
        durationSeconds: 0,
        accumulatedPausedMs: 0
      };
    }
  }

  assert.equal(storage.progress.completedFocusRounds, 4);
  assert.equal(storage.timerState.mode, 'break');
  assert.equal(storage.timerState.taskTitle, '长歇息');
  assert.equal(storage.timerState.durationSeconds, 900);

  const breakState = timer.startBreak();
  assert.equal(breakState.status, 'running');
  assert.equal(breakState.taskTitle, '长歇息');
  assert.equal(breakState.durationSeconds, 900);
}

{
  const storage = createMemoryStorage();
  const nowRef = { now: 9_000_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(1500, 'task_1', '写方案', '工作');
  advancePresent(nowRef, timer, 120_000);
  const rescuedState = timer.shrinkCurrentFocusRemaining(60);

  assert.equal(rescuedState.status, 'running');
  assert.equal(timer.getRemainingSeconds(), 1380);
  assert.equal(rescuedState.durationSeconds, 1500);
  assert.equal(rescuedState.expectedEndAt, 9_000_000 + 1500 * 1000);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '写方案',
    estimatedFocusCount: 1,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 10_000_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(1500, 'task_1', '写方案', '工作');
  advancePresent(nowRef, timer, 170_000);
  assert.equal(timer.completeEarly(180), null);

  advancePresent(nowRef, timer, 15_000);
  const session = timer.completeEarly(180);
  assert.equal(session, null);
  assert.equal(storage.sessions.length, 0);
  assert.equal(storage.tasks[0].completedFocusCount, 0);
  assert.equal(storage.timerState.status, 'running');
}

{
  const storage = createMemoryStorage();
  const nowRef = { now: 10_500_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(300, 'task_1', '写方案', '工作', undefined, 'high', 'recent_abandon');
  advancePresent(nowRef, timer, 300_000);
  timer.restore();

  assert.equal(storage.sessions.length, 1);
  assert.equal(storage.sessions[0].status, 'completed');
  assert.equal(storage.sessions[0].plannedDurationSeconds, 300);
  assert.equal(storage.sessions[0].starterPlanRiskLevel, 'high');
  assert.equal(storage.sessions[0].starterPlanReason, 'recent_abandon');
  assert.equal(storage.sessions[0].starterPlanDurationSeconds, 300);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '写方案',
    estimatedFocusCount: 1,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 11_000_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(1500, 'task_1', '写方案', '工作');
  nowRef.now += 60_000;
  timer.pauseForBackground();

  assert.equal(storage.timerState.status, 'idle');
  assert.equal(storage.sessions.length, 1);
  assert.equal(storage.sessions[0].status, 'abandoned');
  assert.equal(storage.sessions[0].abandonReason, 'distracted');
  assert.equal(storage.sessions[0].focusIntegrityStatus, 'violated');
  assert.equal(storage.sessions[0].focusIntegrityViolationReason, 'left_app');
  assert.equal(storage.sessions[0].timeCoinsEarned || 0, 0);
  assert.equal(storage.tasks[0].completedFocusCount, 0);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '写方案',
    estimatedFocusCount: 1,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 12_000_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(60, 'task_1', '写方案', '工作');
  nowRef.now += 60 * 60 * 1000;
  timer.restore();

  assert.equal(storage.timerState.status, 'idle');
  assert.equal(storage.sessions.length, 1);
  assert.equal(storage.sessions[0].status, 'abandoned');
  assert.equal(storage.sessions[0].abandonReason, 'distracted');
  assert.equal(storage.sessions[0].focusIntegrityStatus, 'violated');
  assert.equal(storage.sessions[0].focusIntegrityViolationReason, 'stale_presence');
  assert.equal(storage.sessions[0].timeCoinsEarned || 0, 0);
  assert.equal(storage.tasks[0].completedFocusCount, 0);
  assert.equal(timer.getRemainingSeconds(), 0);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '写方案',
    estimatedFocusCount: 1,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 12_500_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(300, 'task_1', '写方案', '工作');
  advancePresent(nowRef, timer, 60_000);
  timer.pauseForBackground();

  assert.equal(storage.timerState.status, 'idle');
  assert.equal(storage.sessions.length, 1);
  assert.equal(storage.sessions[0].status, 'abandoned');
  assert.equal(storage.sessions[0].focusIntegrityStatus, 'violated');
  assert.equal(storage.sessions[0].focusIntegrityViolationReason, 'left_app');
  assert.equal(storage.sessions[0].countsAsFocus, false);
  assert.equal(storage.tasks[0].completedFocusCount, 0);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '写方案',
    estimatedFocusCount: 1,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 12_800_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(120, 'task_1', '写方案', '工作');
  advancePresent(nowRef, timer, 110_000);
  timer.pauseForBackground();

  assert.equal(storage.timerState.status, 'idle');
  assert.equal(storage.sessions.length, 1);
  assert.equal(storage.sessions[0].status, 'abandoned');
  assert.equal(storage.sessions[0].timeCoinsEarned || 0, 0);
  assert.equal(storage.tasks[0].completedFocusCount, 0);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '写方案',
    estimatedFocusCount: 1,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 12_900_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(300, 'task_1', '写方案', '工作');
  advancePresent(nowRef, timer, 30_000);
  timer.pauseForBackground();
  const state = timer.shrinkCurrentFocusRemaining(60);

  assert.equal(state.status, 'idle');
  assert.equal(storage.sessions.length, 1);
  assert.equal(storage.sessions[0].status, 'abandoned');
}

{
  const storage = createMemoryStorage();
  const nowRef = { now: 13_000_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(300, 'task_1', '写方案', '工作');
  advancePresent(nowRef, timer, 20_000);
  timer.startAbandonGuard('distracted');
  nowRef.now += 20_000;
  const session = timer.abandon('distracted');

  assert.equal(session.status, 'abandoned');
  assert.equal(session.abandonReason, 'distracted');
  assert.equal(session.actualDurationSeconds, 40);
  assert.match(session.handoffNote, /下次先回到这一小步/);
  assert.equal(storage.timerState.status, 'idle');
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '写方案',
    estimatedFocusCount: 2,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 14_000_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(300, 'task_1', '写方案', '工作');
  advancePresent(nowRef, timer, 20_000);
  const abandonedSession = timer.abandon('blocked');
  assert.equal(abandonedSession.status, 'abandoned');
  assert.equal(storage.tasks[0].completedFocusCount, 0);

  timer.startFocus(60, 'task_1', '写方案', '工作', abandonedSession.id);
  advancePresent(nowRef, timer, 60_000);
  timer.restore();

  assert.equal(storage.sessions.length, 2);
  assert.equal(storage.sessions[0].status, 'completed');
  assert.equal(storage.sessions[0].actualDurationSeconds, 60);
  assert.equal(storage.sessions[0].restartFromSessionId, abandonedSession.id);
  assert.equal(storage.sessions[0].restartFromReason, 'abandoned_retry');
  assert.equal(storage.tasks[0].completedFocusCount, 0);
  assert.equal(storage.progress.completedFocusRounds, 0);
}

{
  const storage = createMemoryStorage();
  const nowRef = { now: 14_500_000 };
  const timer = createTimerCore(storage, nowRef);

  const result = timer.tryStartFocus(60, 'task_1', '首次专注', '工作');
  assert.equal(result.didStart, true);
  assert.equal(timer.getRecoveryGate().isRequired, false);
  assert.equal(storage.timerState.taskTitle, '首次专注');
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '写方案',
    estimatedFocusCount: 2,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 15_000_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(1500, 'task_1', '写方案', '工作');
  advancePresent(nowRef, timer, 20_000);
  const abandonedSession = timer.abandon('distracted');
  const blockedResult = timer.tryStartFocus(1500, 'task_1', '写方案', '工作');

  assert.equal(blockedResult.didStart, false);
  assert.equal(blockedResult.recoveryRequiredSessionId, abandonedSession.id);
  assert.match(blockedResult.message, /1 分钟恢复/);

  const firstRecovery = timer.tryStartFocus(1500, 'task_1', '写方案', '工作', abandonedSession.id);
  assert.equal(firstRecovery.didStart, true);
  assert.equal(firstRecovery.state.durationSeconds, 60);
  assert.equal(firstRecovery.state.recoveryStepIndex, 0);
  advancePresent(nowRef, timer, 60_000);
  timer.restore();
  assert.equal(storage.sessions[0].restartFromReason, 'abandoned_retry');
  assert.equal(storage.sessions[0].countsAsFocus, false);
  assert.equal(storage.sessions[0].timeCoinsEarned || 0, 0);
  assert.equal(storage.tasks[0].completedFocusCount, 0);

  storage.timerState = {
    id: '',
    mode: 'focus',
    status: 'idle',
    durationSeconds: 0,
    accumulatedPausedMs: 0
  };
  const stillBlocked = timer.tryStartFocus(1500, 'task_1', '写方案', '工作');
  assert.equal(stillBlocked.didStart, false);
  assert.match(stillBlocked.message, /3 分钟恢复/);

  const secondRecovery = timer.tryStartFocus(1500, 'task_1', '写方案', '工作', storage.sessions[0].id);
  assert.equal(secondRecovery.didStart, true);
  assert.equal(secondRecovery.state.durationSeconds, 3 * 60);
  assert.equal(secondRecovery.state.recoveryStepIndex, 1);
  advancePresent(nowRef, timer, 3 * 60_000);
  timer.restore();
  storage.timerState = {
    id: '',
    mode: 'focus',
    status: 'idle',
    durationSeconds: 0,
    accumulatedPausedMs: 0
  };

  const thirdRecovery = timer.tryStartFocus(1500, 'task_1', '写方案', '工作', storage.sessions[0].id);
  assert.equal(thirdRecovery.didStart, true);
  assert.equal(thirdRecovery.state.durationSeconds, 5 * 60);
  assert.equal(thirdRecovery.state.recoveryStepIndex, 2);
  advancePresent(nowRef, timer, 5 * 60_000);
  timer.restore();
  assert.equal(storage.sessions[0].recoveryGateCleared, true);
  storage.timerState = {
    id: '',
    mode: 'focus',
    status: 'idle',
    durationSeconds: 0,
    accumulatedPausedMs: 0
  };

  const normalResult = timer.tryStartFocus(1500, 'task_1', '写方案', '工作');
  assert.equal(normalResult.didStart, true);
  assert.equal(normalResult.state.restartFromReason, undefined);
  assert.equal(normalResult.state.durationSeconds, 1500);
}

{
  const storage = createMemoryStorage();
  storage.tasks.push({
    id: 'task_1',
    title: '深度工作',
    estimatedFocusCount: 2,
    completedFocusCount: 0,
    status: 'active'
  });
  const nowRef = { now: 16_000_000 };
  const timer = createTimerCore(storage, nowRef);

  timer.startFocus(29 * 60 + 59, 'task_1', '深度工作', '工作');
  advancePresent(nowRef, timer, (29 * 60 + 59) * 1000);
  timer.restore();
  assert.equal(storage.sessions[0].status, 'completed');
  assert.equal(storage.sessions[0].timeCoinsEarned || 0, 0);
  storage.timerState = {
    id: '',
    mode: 'focus',
    status: 'idle',
    durationSeconds: 0,
    accumulatedPausedMs: 0
  };

  timer.startFocus(30 * 60, 'task_1', '深度工作', '工作');
  advancePresent(nowRef, timer, 30 * 60_000);
  timer.restore();
  assert.equal(storage.sessions[0].timeCoinsEarned, 30);
  storage.timerState = {
    id: '',
    mode: 'focus',
    status: 'idle',
    durationSeconds: 0,
    accumulatedPausedMs: 0
  };

  timer.startFocus(45 * 60, 'task_1', '深度工作', '工作');
  advancePresent(nowRef, timer, 45 * 60_000);
  timer.restore();
  assert.equal(storage.sessions[0].timeCoinsEarned, 45);
}

{
  const storage = createMemoryStorage();
  const nowRef = { now: Date.parse('2026-06-25T08:00:00.000Z') };
  const timer = createTimerCore(storage, nowRef);
  storage.sessions.unshift({
    id: 'session_existing',
    status: 'completed',
    plannedDurationSeconds: 120 * 60,
    actualDurationSeconds: 120 * 60,
    startedAt: nowRef.now - 120 * 60_000,
    endedAt: nowRef.now - 60_000,
    timeCoinsEarned: 230
  });

  timer.startFocus(60 * 60, 'task_1', '深度工作', '工作');
  advancePresent(nowRef, timer, 60 * 60_000);
  timer.restore();

  assert.equal(storage.sessions[0].timeCoinsEarned, 10);
  assert.equal(storage.sessions[0].timeCoinsDailyCap, TIME_COIN_DAILY_CAP);
  assert.equal(storage.sessions[0].timeCoinsSessionCap, TIME_COIN_MAX_PER_SESSION);
}

console.log('timer core tests passed');
