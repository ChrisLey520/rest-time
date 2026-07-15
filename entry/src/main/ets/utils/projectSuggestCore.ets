import { FocusSession } from '../models/FocusSession';
import { Task } from '../models/Task';

export const PROJECT_SUGGESTION_LIMIT = 6;

interface ProjectUsage {
  projectName: string;
  usageCount: number;
  lastUsedAt: number;
}

function recordUsage(usages: ProjectUsage[], projectName?: string, usedAt: number = 0): void {
  const trimmedProjectName = projectName ? projectName.trim() : '';
  if (!trimmedProjectName) {
    return;
  }

  let usage = usages.find((item: ProjectUsage) => item.projectName === trimmedProjectName);
  if (!usage) {
    usage = {
      projectName: trimmedProjectName,
      usageCount: 0,
      lastUsedAt: 0
    };
    usages.push(usage);
  }

  usage.usageCount += 1;
  if (usedAt > usage.lastUsedAt) {
    usage.lastUsedAt = usedAt;
  }
}

export function suggestProjectNames(
  tasks: Task[],
  sessions: FocusSession[],
  limit: number = PROJECT_SUGGESTION_LIMIT
): string[] {
  const usages: ProjectUsage[] = [];
  tasks.forEach((task: Task) => {
    recordUsage(usages, task.projectName, task.createdAt);
  });
  sessions.forEach((session: FocusSession) => {
    recordUsage(usages, session.projectName, session.endedAt);
  });

  usages.sort((left: ProjectUsage, right: ProjectUsage) => {
    if (right.usageCount !== left.usageCount) {
      return right.usageCount - left.usageCount;
    }

    return right.lastUsedAt - left.lastUsedAt;
  });

  return usages
    .slice(0, Math.max(0, Math.floor(limit)))
    .map((usage: ProjectUsage) => usage.projectName);
}
