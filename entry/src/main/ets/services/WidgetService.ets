import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import { formatSeconds } from '../utils/dateTime';
import { TimerState } from '../models/TimerState';
import { ErrorLogService } from './ErrorLogService';
import { StatsService } from './StatsService';
import { StorageService, WidgetFormIds } from './StorageService';
import { TimerService } from './TimerService';

export interface WidgetSnapshot {
  todayFocusSeconds: number;
  goalMinutes: number;
  goalProgressPercent: number;
  currentTaskTitle: string;
  timerStatus: string;
  pauseReason: string;
  guardStatus: string;
  awayCount: number;
  awaySeconds: number;
  microActionText: string;
  microActionCompletedCount: number;
  returnProofRemainingSeconds: number;
  returnProofRequiredCount: number;
  returnProofCompletedCount: number;
  focusIntegrityStatus: string;
  focusIntegrityViolationReason: string;
  focusIntegrityViolationCount: number;
  remainingSeconds: number;
  updatedAt: number;
}

export interface WidgetCardData {
  brandName: string;
  headline: string;
  detail: string;
  taskTitle: string;
  remainingText: string;
  todayText: string;
  goalText: string;
  statusText: string;
  updatedAt: number;
}

export class WidgetService {
  static async getSnapshot(): Promise<WidgetSnapshot> {
    const state: TimerState = await TimerService.restore();
    const remainingSeconds = await TimerService.getRemainingSeconds();
    const stats = await StatsService.getTodayStats();
    const goalStats = await StatsService.getGoalStats();

    return {
      todayFocusSeconds: stats.focusSeconds,
      goalMinutes: goalStats.goalMinutes,
      goalProgressPercent: goalStats.progressPercent,
      currentTaskTitle: state.taskTitle ? state.taskTitle : '自由专注',
      timerStatus: state.status,
      pauseReason: state.pauseReason ? state.pauseReason : '',
      guardStatus: state.guardStatus ? state.guardStatus : '',
      awayCount: state.awayCount ? state.awayCount : 0,
      awaySeconds: TimerService.awaySeconds(state),
      microActionText: state.microActionText ? state.microActionText : '',
      microActionCompletedCount: state.microActionCompletedCount ? state.microActionCompletedCount : 0,
      returnProofRemainingSeconds: TimerService.returnProofRemainingSeconds(state),
      returnProofRequiredCount: state.returnProofRequiredCount ? state.returnProofRequiredCount : 0,
      returnProofCompletedCount: state.returnProofCompletedCount ? state.returnProofCompletedCount : 0,
      focusIntegrityStatus: state.focusIntegrityStatus ? state.focusIntegrityStatus : '',
      focusIntegrityViolationReason: state.focusIntegrityViolationReason ? state.focusIntegrityViolationReason : '',
      focusIntegrityViolationCount: state.focusIntegrityViolationCount ? state.focusIntegrityViolationCount : 0,
      remainingSeconds,
      updatedAt: Date.now()
    };
  }

  static defaultCardData(): WidgetCardData {
    return {
      brandName: '栖时',
      headline: '准备专注',
      detail: '今日还没有安放时间',
      taskTitle: '自由专注',
      remainingText: '--:--',
      todayText: '今日 0 分钟',
      goalText: '目标 0%',
      statusText: '空闲',
      updatedAt: Date.now()
    };
  }

  static async getCardData(): Promise<WidgetCardData> {
    const snapshot = await WidgetService.getSnapshot();
    const focusMinutes = Math.floor(snapshot.todayFocusSeconds / 60);
    let headline = '准备专注';
    let detail = '轻轻开始一段新的时间';
    let statusText = '空闲';
    let remainingText = '--:--';

    if (snapshot.timerStatus === 'running') {
      headline = '正在专注';
      detail = snapshot.microActionText ? snapshot.microActionText : '剩余时间';
      statusText = '进行中';
      remainingText = formatSeconds(snapshot.remainingSeconds);
      if (snapshot.returnProofRemainingSeconds > 0) {
        headline = '守门整理中';
        detail = '本轮失败，回到 App 留下下一步';
        statusText = '整理中';
      }
      if (snapshot.guardStatus === 'cooling') {
        headline = '别急着结束';
        detail = '回到 App 继续这一段';
        statusText = '退出缓冲';
      }
    } else if (snapshot.timerStatus === 'paused') {
      headline = '专注已中断';
      detail = '本轮不可结算';
      statusText = '已中断';
      remainingText = formatSeconds(snapshot.remainingSeconds);
      if (snapshot.pauseReason === 'background') {
        headline = '专注已终止';
        detail = snapshot.awaySeconds > 0
          ? `已离开 ${formatSeconds(snapshot.awaySeconds)}，本轮无奖励`
          : '离开 App 后本轮失败';
        statusText = '已失败';
        if (snapshot.focusIntegrityStatus === 'violated') {
          headline = '守门已触发';
          detail = '本轮失败且无时光币';
          statusText = '不可结算';
        }
      }
    } else if (snapshot.remainingSeconds > 0) {
      headline = '可以歇息';
      detail = '建议歇息时长';
      statusText = '待歇息';
      remainingText = formatSeconds(snapshot.remainingSeconds);
    }

    return {
      brandName: '栖时',
      headline,
      detail,
      taskTitle: snapshot.currentTaskTitle,
      remainingText,
      todayText: `今日 ${focusMinutes}/${snapshot.goalMinutes} 分钟`,
      goalText: `目标 ${snapshot.goalProgressPercent}%`,
      statusText,
      updatedAt: snapshot.updatedAt
    };
  }

  static createBindingData(data: WidgetCardData): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(data);
  }

  static async addFormId(formId: string): Promise<void> {
    if (!formId) {
      return;
    }

    const storedIds = await WidgetService.getFormIds();
    if (storedIds.ids.indexOf(formId) < 0) {
      storedIds.ids.push(formId);
      await StorageService.saveWidgetFormIds(storedIds);
    }
  }

  static async removeFormId(formId: string): Promise<void> {
    const storedIds = await WidgetService.getFormIds();
    const nextIds: WidgetFormIds = {
      ids: storedIds.ids.filter((id: string) => id !== formId)
    };
    await StorageService.saveWidgetFormIds(nextIds);
  }

  static async refreshForm(formId: string): Promise<void> {
    if (!formId) {
      return;
    }

    try {
      const data = await WidgetService.getCardData();
      await formProvider.updateForm(formId, WidgetService.createBindingData(data));
      await WidgetService.scheduleNextRefresh(formId, data);
    } catch (error) {
      // The host can remove or throttle cards; the app state should not fail because of it.
      await ErrorLogService.record('widget', `卡片刷新失败：${error instanceof Error ? error.message : error}`);
    }
  }

  static async refreshAllForms(): Promise<void> {
    const storedIds = await WidgetService.getFormIds();
    for (let index = 0; index < storedIds.ids.length; index += 1) {
      await WidgetService.refreshForm(storedIds.ids[index]);
    }
  }

  private static async getFormIds(): Promise<WidgetFormIds> {
    return StorageService.getWidgetFormIds();
  }

  private static async scheduleNextRefresh(formId: string, data: WidgetCardData): Promise<void> {
    if (data.statusText === '进行中') {
      try {
        await formProvider.setFormNextRefreshTime(formId, 1);
      } catch (error) {
        // The form host may reject frequent refresh scheduling; keep the card update best-effort.
      }
    }
  }
}
