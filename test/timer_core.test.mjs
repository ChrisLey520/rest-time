import assert from 'node:assert/strict';

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
      roundsBeforeLongBreak: 4
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

  return {
    isFocusStartBlocked() {
      const state = storage.timerState;
      return state.status === 'running' || state.status === 'paused' || state.mode === 'break';
    },

    tryStartFocus(durationSeconds = 60, taskId = 'task_1', taskTitle = '自由专注') {
      if (this.isFocusStartBlocked()) {
        return {
          didStart: false,
          state: storage.timerState,
          message: 'blocked'
        };
      }

      return {
        didStart: true,
        state: this.startFocus(durationSeconds, taskId, taskTitle),
        message: ''
      };
    },

    startFocus(durationSeconds = 60, taskId = 'task_1', taskTitle = '自由专注') {
      if (this.isFocusStartBlocked()) {
        return storage.timerState;
      }

      const now = nowRef.now;
      storage.timerState = {
        id: `timer_${now}`,
        mode: 'focus',
        status: 'running',
        taskId,
        taskTitle,
        startedAt: now,
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

    pause() {
      const state = storage.timerState;
      if (state.status !== 'running') return state;
      state.status = 'paused';
      state.pausedAt = nowRef.now;
      return state;
    },

    resume() {
      const state = storage.timerState;
      if (state.status !== 'paused' || !state.pausedAt || !state.expectedEndAt) return state;
      const pausedMs = nowRef.now - state.pausedAt;
      state.status = 'running';
      state.expectedEndAt += pausedMs;
      state.accumulatedPausedMs += pausedMs;
      state.pausedAt = undefined;
      return state;
    },

    complete() {
      const state = storage.timerState;
      if (state.status === 'idle' || !state.startedAt || !state.expectedEndAt) return null;
      const session = {
        id: `session_${nowRef.now}`,
        taskTitle: state.taskTitle,
        plannedDurationSeconds: state.durationSeconds,
        actualDurationSeconds: state.durationSeconds,
        startedAt: state.startedAt,
        endedAt: state.expectedEndAt,
        status: 'completed'
      };
      storage.sessions.unshift(session);
      const task = storage.tasks.find((item) => item.id === state.taskId);
      if (task) {
        task.completedFocusCount += 1;
      }
      storage.progress.completedFocusRounds += 1;
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
    },

    abandon() {
      const state = storage.timerState;
      if (state.status === 'idle' || !state.startedAt) return null;
      const pausedExtraMs = state.status === 'paused' && state.pausedAt ? nowRef.now - state.pausedAt : 0;
      const actualDurationSeconds = Math.max(
        0,
        Math.floor((nowRef.now - state.startedAt - state.accumulatedPausedMs - pausedExtraMs) / 1000)
      );
      const session = {
        id: `session_${nowRef.now}`,
        taskTitle: state.taskTitle,
        plannedDurationSeconds: state.durationSeconds,
        actualDurationSeconds,
        startedAt: state.startedAt,
        endedAt: nowRef.now,
        status: 'abandoned'
      };
      storage.sessions.unshift(session);
      storage.timerState = idle();
      return session;
    },

    restore() {
      const state = storage.timerState;
      if (state.status === 'idle') return state;
      if (state.status === 'running' && state.expectedEndAt <= nowRef.now) {
        if (state.mode === 'break') {
          storage.timerState = idle();
        } else {
          this.complete();
        }
        return storage.timerState;
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

  timer.startFocus(60);
  assert.equal(timer.getRemainingSeconds(), 60);

  nowRef.now += 10_000;
  assert.equal(timer.getRemainingSeconds(), 50);

  timer.pause();
  nowRef.now += 20_000;
  assert.equal(timer.getRemainingSeconds(), 50);

  timer.resume();
  assert.equal(timer.getRemainingSeconds(), 50);
  assert.equal(storage.timerState.accumulatedPausedMs, 20_000);

  nowRef.now += 50_000;
  timer.restore();
  assert.equal(storage.timerState.status, 'idle');
  assert.equal(storage.timerState.mode, 'break');
  assert.equal(storage.timerState.taskTitle, '歇息');
  assert.equal(timer.getRemainingSeconds(), 300);
  assert.equal(storage.sessions.length, 1);
  assert.equal(storage.sessions[0].status, 'completed');
  assert.equal(storage.sessions[0].actualDurationSeconds, 60);
  assert.equal(storage.tasks[0].completedFocusCount, 1);
  assert.equal(storage.progress.completedFocusRounds, 1);
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

  timer.startFocus(60);
  nowRef.now += 12_200;
  const session = timer.abandon();

  assert.equal(session.status, 'abandoned');
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
    nowRef.now += 60_000;
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

console.log('timer core tests passed');
