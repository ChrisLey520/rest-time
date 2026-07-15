export const PROJECT_SUGGESTION_LIMIT = 6;

function recordUsage(usages, projectName, usedAt = 0) {
  const trimmedProjectName = projectName ? projectName.trim() : '';
  if (!trimmedProjectName) {
    return;
  }

  let usage = usages.find((item) => item.projectName === trimmedProjectName);
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

export function suggestProjectNames(tasks, sessions, limit = PROJECT_SUGGESTION_LIMIT) {
  const usages = [];
  tasks.forEach((task) => {
    recordUsage(usages, task.projectName, task.createdAt);
  });
  sessions.forEach((session) => {
    recordUsage(usages, session.projectName, session.endedAt);
  });

  usages.sort((left, right) => {
    if (right.usageCount !== left.usageCount) {
      return right.usageCount - left.usageCount;
    }

    return right.lastUsedAt - left.lastUsedAt;
  });

  return usages
    .slice(0, Math.max(0, Math.floor(limit)))
    .map((usage) => usage.projectName);
}
