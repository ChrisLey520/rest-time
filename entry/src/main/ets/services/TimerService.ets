import { FocusSession } from '../models/FocusSession';
import { idleTimerState, TimerState } from '../models/TimerState';
import { createId } from '../utils/id';
import { SessionService } from './SessionService';
import { StorageService } from './StorageService';
import { TaskService } from './TaskService';
import { NotificationService } from './NotificationService';
import { PomodoroProgressService } from './PomodoroProgressService';

function cloneIdleState(): TimerState {
  return {
    id: '',
    mode: 'focus',
    status: 'idle',
    durationSeconds: 0,
    accumulatedPausedMs: 0
  };
}

export interface TimerStartResult {
  didStart: boolean;
  state: TimerState;
  message: string;
}

export class TimerService {
  static isFocusStartBlocked(state: TimerState): boolean {
    return state.status === 'running' || state.status === 'paused' || state.mode === 'break';
  }

  static async canStartFocus(): Promise<boolean> {
    const state = await TimerService.restore();
    return !TimerService.isFocusStartBlocked(state);
  }

  static async tryStartFocus(durationSeconds?: number, taskId?: string, taskTitle?: string): Promise<TimerStartResult> {
    const currentState = await TimerService.restore();
    if (TimerService.isFocusStartBlocked(currentState)) {
      const blockedResult: TimerStartResult = {
        didStart: false,
        state: currentState,
        message: TimerService.focusStartBlockedMessage(currentState)
      };
      return blockedResult;
    }

    const state = await TimerService.createFocusTimer(durationSeconds, taskId, taskTitle);
    const startedResult: TimerStartResult = {
      didStart: true,
      state,
      message: ''
    };
    return startedResult;
  }

  static async startFocus(durationSeconds?: number, taskId?: string, taskTitle?: string): Promise<TimerState> {
    const result = await TimerService.tryStartFocus(durationSeconds, taskId, taskTitle);
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

  private static async createFocusTimer(durationSeconds?: number, taskId?: string, taskTitle?: string): Promise<TimerState> {
    const config = await StorageService.getConfig();
    const plannedDurationSeconds = durationSeconds ? durationSeconds : config.focusMinutes * 60;
    const now = Date.now();
    const state: TimerState = {
      id: createId('timer'),
      mode: 'focus',
      status: 'running',
      taskId,
      taskTitle,
      startedAt: now,
      expectedEndAt: now + plannedDurationSeconds * 1000,
      durationSeconds: plannedDurationSeconds,
      accumulatedPausedMs: 0
    };

    await StorageService.saveTimerState(state);
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
      return '已有暂停中的专注，已切到专注页';
    }

    return '已有进行中的专注，已切到专注页';
  }

  static async pause(): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (state.status !== 'running') {
      return state;
    }

    state.status = 'paused';
    state.pausedAt = Date.now();
    await StorageService.saveTimerState(state);
    return state;
  }

  static async resume(): Promise<TimerState> {
    const state = await StorageService.getTimerState();
    if (state.status !== 'paused' || !state.pausedAt || !state.expectedEndAt) {
      return state;
    }

    const now = Date.now();
    const pausedMs = now - state.pausedAt;
    state.status = 'running';
    state.expectedEndAt += pausedMs;
    state.accumulatedPausedMs += pausedMs;
    state.pausedAt = undefined;

    await StorageService.saveTimerState(state);
    return state;
  }

  static async abandon(): Promise<FocusSession | null> {
    const state = await StorageService.getTimerState();
    if (state.status === 'idle' || !state.startedAt) {
      return null;
    }

    if (state.mode === 'break') {
      await TimerService.clearTimer();
      return null;
    }

    const now = Date.now();
    const pausedExtraMs = state.status === 'paused' && state.pausedAt ? now - state.pausedAt : 0;
    const actualDurationSeconds = Math.max(
      0,
      Math.floor((now - state.startedAt - state.accumulatedPausedMs - pausedExtraMs) / 1000)
    );
    const session: FocusSession = {
      id: createId('session'),
      taskId: state.taskId,
      taskTitle: state.taskTitle,
      plannedDurationSeconds: state.durationSeconds,
      actualDurationSeconds,
      startedAt: state.startedAt,
      endedAt: now,
      status: 'abandoned'
    };

    await SessionService.add(session);
    await TimerService.clearTimer();
    return session;
  }

  static async complete(): Promise<FocusSession | null> {
    const state = await StorageService.getTimerState();
    if (state.status === 'idle' || state.mode !== 'focus' || !state.startedAt || !state.expectedEndAt) {
      return null;
    }

    const session: FocusSession = {
      id: createId('session'),
      taskId: state.taskId,
      taskTitle: state.taskTitle,
      plannedDurationSeconds: state.durationSeconds,
      actualDurationSeconds: state.durationSeconds,
      startedAt: state.startedAt,
      endedAt: state.expectedEndAt,
      status: 'completed'
    };

    await SessionService.add(session);
    await TaskService.incrementCompletedFocusCount(state.taskId);
    await NotificationService.notifyFocusCompleted(Math.round(state.durationSeconds / 60));
    const completedRounds = await PomodoroProgressService.incrementFocusRounds();
    await TimerService.prepareBreak(completedRounds);
    return session;
  }

  static async completeBreak(): Promise<void> {
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
