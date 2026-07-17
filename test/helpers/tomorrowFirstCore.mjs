export const TOMORROW_FIRST_EXPIRE_DAYS = 3;

export function createTomorrowFirst(text, taskId, createdAt) {
  const trimmed = text.trim().slice(0, 30);
  if (trimmed.length === 0) {
    return null;
  }

  return {
    text: trimmed,
    taskId,
    createdAt
  };
}

function startOfDay(timestamp) {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

export function tomorrowFirstState(entry, now) {
  if (!entry) {
    return 'expired';
  }

  const daysSince = Math.round((startOfDay(now) - startOfDay(entry.createdAt)) / (24 * 60 * 60 * 1000));
  if (daysSince <= 0) {
    return 'pending';
  }

  if (daysSince <= TOMORROW_FIRST_EXPIRE_DAYS) {
    return 'ready';
  }

  return 'expired';
}

export function tomorrowFirstHeadline(entry, now) {
  const daysSince = Math.round((startOfDay(now) - startOfDay(entry.createdAt)) / (24 * 60 * 60 * 1000));
  if (daysSince <= 1) {
    return '昨晚你说，今天先做这件';
  }

  return `${daysSince} 天前你留了一件事给自己`;
}
