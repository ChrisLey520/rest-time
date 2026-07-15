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
    tasks: [
      {
        id: 'task_1',
        title: '写方案',
        estimatedFocusCount: 2,
        completedFocusCount: 0,
        status: 'active'
      },
      {
        id: 'task_2',
        title: '整理资料',
        estimatedFocusCount: 1,
        completedFocusCount: 0,
        status: 'active'
      }
    ]
  };
}

function createTaskCore(storage) {
  function isTaskLockedByTimer(taskId) {
    const state = storage.timerState;
    return state.mode === 'focus' && state.status !== 'idle' && state.taskId === taskId;
  }

  function normalizeProjectName(projectName) {
    const trimmedProjectName = projectName ? projectName.trim() : '';
    return trimmedProjectName ? trimmedProjectName : undefined;
  }

  return {
    add(title, estimatedFocusCount = 1, priority = 'normal', plannedFor = 'none', projectName = undefined) {
      const trimmedTitle = title.trim();
      if (!trimmedTitle) return null;
      const task = {
        id: `task_${storage.tasks.length + 1}`,
        title: trimmedTitle,
        estimatedFocusCount: Math.max(1, estimatedFocusCount),
        completedFocusCount: 0,
        status: 'active',
        priority,
        plannedFor,
        projectName: normalizeProjectName(projectName)
      };
      storage.tasks.unshift(task);
      return task;
    },

    update(taskId, title, estimatedFocusCount, priority = 'normal', plannedFor = 'none', projectName = undefined) {
      if (isTaskLockedByTimer(taskId)) return null;
      const task = storage.tasks.find((item) => item.id === taskId);
      if (!task) return null;

      task.title = title.trim() || task.title;
      task.estimatedFocusCount = Math.max(1, estimatedFocusCount);
      task.priority = priority;
      task.plannedFor = plannedFor;
      task.projectName = normalizeProjectName(projectName);
      return task;
    },

    updatePlanning(taskId, priority, plannedFor) {
      if (isTaskLockedByTimer(taskId)) return null;
      const task = storage.tasks.find((item) => item.id === taskId);
      if (!task) return null;

      task.priority = priority;
      task.plannedFor = plannedFor;
      return task;
    },

    delete(taskId) {
      if (isTaskLockedByTimer(taskId)) return false;
      storage.tasks = storage.tasks.filter((task) => task.id !== taskId);
      return true;
    },

    markCompleted(taskId) {
      if (isTaskLockedByTimer(taskId)) return null;
      const task = storage.tasks.find((item) => item.id === taskId);
      if (!task) return null;

      task.status = 'completed';
      return task;
    },

    archive(taskId) {
      if (isTaskLockedByTimer(taskId)) return null;
      const task = storage.tasks.find((item) => item.id === taskId);
      if (!task) return null;

      task.status = 'archived';
      return task;
    },

    incrementCompletedFocusCount(taskId) {
      const task = storage.tasks.find((item) => item.id === taskId);
      if (!task) return null;

      task.completedFocusCount += 1;
      if (task.completedFocusCount >= task.estimatedFocusCount) {
        task.status = 'completed';
      }
      return task;
    }
  };
}

{
  const storage = createMemoryStorage();
  const taskCore = createTaskCore(storage);
  const task = taskCore.add('  做发布计划  ', 3, 'high', 'today', '  工作  ');

  assert.equal(task.title, '做发布计划');
  assert.equal(task.priority, 'high');
  assert.equal(task.plannedFor, 'today');
  assert.equal(task.projectName, '工作');

  const updatedTask = taskCore.update(task.id, '复盘数据', 2, 'normal', 'tomorrow', '学习');
  assert.equal(updatedTask.title, '复盘数据');
  assert.equal(updatedTask.estimatedFocusCount, 2);
  assert.equal(updatedTask.priority, 'normal');
  assert.equal(updatedTask.plannedFor, 'tomorrow');
  assert.equal(updatedTask.projectName, '学习');

  const unscopedTask = taskCore.update(task.id, '复盘数据', 2, 'low', 'later', '  ');
  assert.equal(unscopedTask.priority, 'low');
  assert.equal(unscopedTask.plannedFor, 'later');
  assert.equal(unscopedTask.projectName, undefined);
}

{
  const storage = createMemoryStorage();
  const taskCore = createTaskCore(storage);
  const task = taskCore.updatePlanning('task_1', 'high', 'today');

  assert.equal(task.priority, 'high');
  assert.equal(task.plannedFor, 'today');

  storage.timerState = {
    id: 'timer_1',
    mode: 'focus',
    status: 'running',
    taskId: 'task_1',
    taskTitle: '写方案',
    durationSeconds: 1500,
    accumulatedPausedMs: 0
  };
  assert.equal(taskCore.updatePlanning('task_1', 'normal', 'tomorrow'), null);
  assert.equal(storage.tasks[0].priority, 'high');
  assert.equal(storage.tasks[0].plannedFor, 'today');
}

{
  const storage = createMemoryStorage();
  const taskCore = createTaskCore(storage);
  storage.timerState = {
    id: 'timer_1',
    mode: 'focus',
    status: 'running',
    taskId: 'task_1',
    taskTitle: '写方案',
    durationSeconds: 1500,
    accumulatedPausedMs: 0
  };

  assert.equal(taskCore.update('task_1', '新标题', 4), null);
  assert.equal(taskCore.markCompleted('task_1'), null);
  assert.equal(taskCore.archive('task_1'), null);
  assert.equal(taskCore.delete('task_1'), false);
  assert.equal(storage.tasks.length, 2);
  assert.equal(storage.tasks[0].title, '写方案');
  assert.equal(storage.tasks[0].status, 'active');

  assert.equal(taskCore.delete('task_2'), true);
  assert.equal(storage.tasks.length, 1);
}

{
  const storage = createMemoryStorage();
  const taskCore = createTaskCore(storage);
  storage.timerState = {
    id: 'timer_1',
    mode: 'focus',
    status: 'running',
    taskId: 'task_1',
    taskTitle: '写方案',
    durationSeconds: 1500,
    accumulatedPausedMs: 0
  };

  const task = taskCore.incrementCompletedFocusCount('task_1');
  assert.equal(task.completedFocusCount, 1);
  assert.equal(task.status, 'active');

  const completedTask = taskCore.incrementCompletedFocusCount('task_1');
  assert.equal(completedTask.completedFocusCount, 2);
  assert.equal(completedTask.status, 'completed');
}

console.log('task core tests passed');
