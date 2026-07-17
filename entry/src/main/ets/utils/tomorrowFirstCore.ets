// 明日第一件事：结束今天时留一句给明天的自己，次日首次打开直接接上。
// 行为学依据：implementation intention——前一晚具体到「先做什么」的计划
// 显著提升次日执行率；同时消解「打开 App 不知道先做哪件」的启动瘫痪。
export const TOMORROW_FIRST_EXPIRE_DAYS = 3;

export interface TomorrowFirst {
  text: string;
  taskId: string;
  createdAt: number;
}

export function createTomorrowFirst(text: string, taskId: string, createdAt: number): TomorrowFirst | null {
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

function startOfDay(timestamp: number): number {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

export type TomorrowFirstState = 'pending' | 'ready' | 'expired';

/**
 * pending：写下当天，还没到明天——不显示（今天已经收尾了）。
 * ready：写下之后的 1 到 3 天内首次打开——显示承诺卡片。
 * expired：超过 3 天——静默丢弃，不翻旧账。
 */
export function tomorrowFirstState(entry: TomorrowFirst | null, now: number): TomorrowFirstState {
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

export function tomorrowFirstHeadline(entry: TomorrowFirst, now: number): string {
  const daysSince = Math.round((startOfDay(now) - startOfDay(entry.createdAt)) / (24 * 60 * 60 * 1000));
  if (daysSince <= 1) {
    return '昨晚你说，今天先做这件';
  }

  return `${daysSince} 天前你留了一件事给自己`;
}
