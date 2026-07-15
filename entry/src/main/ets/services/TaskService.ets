import { Task, TaskPlannedFor, TaskPriority } from '../models/Task';
import { TimerState } from '../models/TimerState';
import { createId } from '../utils/id';
import { StorageService } from './StorageService';

export class TaskService {
  private static normalizePriority(priority?: TaskPriority): TaskPriority {
    if (priority === 'low' || priority === 'high') {
      return priority;
    }

    return 'normal';
  }

  private static normalizePlannedFor(plannedFor?: TaskPlannedFor): TaskPlannedFor {
    if (plannedFor === 'today' || plannedFor === 'tomorrow' || plannedFor === 'later') {
      return plannedFor;
    }

    return 'none';
  }

  private static normalizeProjectName(projectName?: string): string | undefined {
    const trimmedProjectName = projectName ? projectName.trim() : '';
    return trimmedProjectName ? trimmedProjectName : undefined;
  }

  private static async isTaskLockedByTimer(taskId: string): Promise<boolean> {
    const state: TimerState = await StorageService.getTimerState();
    return state.mode === 'focus' && state.status !== 'idle' && state.taskId === taskId;
  }

  static async listAll(): Promise<Task[]> {
    return StorageService.getTasks();
  }

  static async listActive(): Promise<Task[]> {
    const tasks = await StorageService.getTasks();
    return tasks.filter((task: Task) => task.status === 'active');
  }

  static async add(
    title: string,
    estimatedFocusCount: number = 1,
    priority: TaskPriority = 'normal',
    plannedFor: TaskPlannedFor = 'none',
    projectName?: string
  ): Promise<Task | null> {
    const trimmedTitle = title.trim();
    if (!trimmedTitle) {
      return null;
    }

    const task: Task = {
      id: createId('task'),
      title: trimmedTitle,
      estimatedFocusCount: Math.max(1, estimatedFocusCount),
      completedFocusCount: 0,
      status: 'active',
      priority: TaskService.normalizePriority(priority),
      plannedFor: TaskService.normalizePlannedFor(plannedFor),
      projectName: TaskService.normalizeProjectName(projectName),
      createdAt: Date.now()
    };
    const tasks = await StorageService.getTasks();
    tasks.unshift(task);
    await StorageService.saveTasks(tasks);

    return task;
  }

  static async update(
    taskId: string,
    title: string,
    estimatedFocusCount: number,
    priority: TaskPriority = 'normal',
    plannedFor: TaskPlannedFor = 'none',
    projectName?: string
  ): Promise<Task | null> {
    if (await TaskService.isTaskLockedByTimer(taskId)) {
      return null;
    }

    const tasks = await StorageService.getTasks();
    const index = tasks.findIndex((task: Task) => task.id === taskId);
    if (index < 0) {
      return null;
    }

    tasks[index].title = title.trim() || tasks[index].title;
    tasks[index].estimatedFocusCount = Math.max(1, estimatedFocusCount);
    tasks[index].priority = TaskService.normalizePriority(priority);
    tasks[index].plannedFor = TaskService.normalizePlannedFor(plannedFor);
    tasks[index].projectName = TaskService.normalizeProjectName(projectName);
    await StorageService.saveTasks(tasks);

    return tasks[index];
  }

  static async updatePlanning(
    taskId: string,
    priority: TaskPriority,
    plannedFor: TaskPlannedFor
  ): Promise<Task | null> {
    if (await TaskService.isTaskLockedByTimer(taskId)) {
      return null;
    }

    const tasks = await StorageService.getTasks();
    const task = tasks.find((item: Task) => item.id === taskId);
    if (!task) {
      return null;
    }

    task.priority = TaskService.normalizePriority(priority);
    task.plannedFor = TaskService.normalizePlannedFor(plannedFor);
    await StorageService.saveTasks(tasks);

    return task;
  }

  static async delete(taskId: string): Promise<boolean> {
    if (await TaskService.isTaskLockedByTimer(taskId)) {
      return false;
    }

    const tasks = await StorageService.getTasks();
    await StorageService.saveTasks(tasks.filter((task: Task) => task.id !== taskId));
    return true;
  }

  static async markCompleted(taskId: string): Promise<Task | null> {
    if (await TaskService.isTaskLockedByTimer(taskId)) {
      return null;
    }

    const tasks = await StorageService.getTasks();
    const task = tasks.find((item: Task) => item.id === taskId);
    if (!task) {
      return null;
    }

    task.status = 'completed';
    task.completedAt = Date.now();
    await StorageService.saveTasks(tasks);

    return task;
  }

  static async restore(taskId: string): Promise<Task | null> {
    const tasks = await StorageService.getTasks();
    const task = tasks.find((item: Task) => item.id === taskId);
    if (!task) {
      return null;
    }

    task.status = 'active';
    await StorageService.saveTasks(tasks);

    return task;
  }

  static async archive(taskId: string): Promise<Task | null> {
    if (await TaskService.isTaskLockedByTimer(taskId)) {
      return null;
    }

    const tasks = await StorageService.getTasks();
    const task = tasks.find((item: Task) => item.id === taskId);
    if (!task) {
      return null;
    }

    task.status = 'archived';
    await StorageService.saveTasks(tasks);

    return task;
  }

  static async incrementCompletedFocusCount(taskId?: string): Promise<Task | null> {
    if (!taskId) {
      return null;
    }

    const tasks = await StorageService.getTasks();
    const task = tasks.find((item: Task) => item.id === taskId);
    if (!task) {
      return null;
    }

    task.completedFocusCount += 1;
    if (task.completedFocusCount >= task.estimatedFocusCount) {
      task.status = 'completed';
      task.completedAt = Date.now();
    }

    await StorageService.saveTasks(tasks);
    return task;
  }
}
