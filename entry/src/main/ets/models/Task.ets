export type TaskStatus = 'active' | 'completed' | 'archived';
export type TaskPriority = 'low' | 'normal' | 'high';
export type TaskPlannedFor = 'none' | 'today' | 'tomorrow' | 'later';

export interface Task {
  id: string;
  title: string;
  estimatedFocusCount: number;
  completedFocusCount: number;
  status: TaskStatus;
  priority?: TaskPriority;
  plannedFor?: TaskPlannedFor;
  projectName?: string;
  createdAt: number;
  completedAt?: number;
}
