import { appendErrorLog, ErrorLogEntry, ErrorLogSource, errorSourceLabel } from '../utils/errorLogCore';
import { StorageService } from './StorageService';

export { ErrorLogEntry, ErrorLogSource, errorSourceLabel };

export class ErrorLogService {
  static async record(source: ErrorLogSource, message: string): Promise<void> {
    try {
      const entries = await StorageService.getErrorLogs();
      await StorageService.saveErrorLogs(appendErrorLog(entries, source, message, Date.now()));
    } catch (error) {
      // 错误日志本身失败时静默，不能影响主流程。
    }
  }

  static async listAll(): Promise<ErrorLogEntry[]> {
    try {
      return await StorageService.getErrorLogs();
    } catch (error) {
      return [];
    }
  }

  static async clearAll(): Promise<void> {
    try {
      await StorageService.saveErrorLogs([]);
    } catch (error) {
      // 清空失败时保持现状即可。
    }
  }
}
