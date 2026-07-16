export type ErrorLogSource =
  | 'reminder'
  | 'storage'
  | 'widget'
  | 'notification'
  | 'export'
  | 'runtime';

export interface ErrorLogEntry {
  at: number;
  source: ErrorLogSource;
  message: string;
}

export const ERROR_LOG_LIMIT = 50;

function normalizeMessage(message: string): string {
  const trimmedMessage = message ? message.trim() : '';
  if (!trimmedMessage) {
    return '未知错误';
  }

  return trimmedMessage.slice(0, 200);
}

export function appendErrorLog(
  entries: ErrorLogEntry[],
  source: ErrorLogSource,
  message: string,
  at: number,
  limit: number = ERROR_LOG_LIMIT
): ErrorLogEntry[] {
  const next = entries.slice();
  next.unshift({
    at,
    source,
    message: normalizeMessage(message)
  });

  return next.slice(0, Math.max(1, Math.floor(limit)));
}

export function errorSourceLabel(source: ErrorLogSource): string {
  if (source === 'reminder') {
    return '系统提醒';
  }

  if (source === 'storage') {
    return '本地存储';
  }

  if (source === 'widget') {
    return '服务卡片';
  }

  if (source === 'notification') {
    return '通知';
  }

  if (source === 'export') {
    return '导出';
  }

  return '运行时';
}
