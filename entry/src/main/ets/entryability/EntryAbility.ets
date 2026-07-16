import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { ErrorLogService } from '../services/ErrorLogService';
import { NotificationService } from '../services/NotificationService';
import { ReminderService } from '../services/ReminderService';
import { StorageService } from '../services/StorageService';
import { TimerService } from '../services/TimerService';
import { WidgetService } from '../services/WidgetService';

export default class EntryAbility extends UIAbility {
  private windowStage?: window.WindowStage;

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
    this.loadContent(windowStage);
  }

  onForeground(): void {
    this.syncRuntimeState();
  }

  onBackground(): void {
    this.pauseFocusForBackground('left_app');
  }

  onDestroy(): void {
    this.pauseFocusForBackground('app_terminated');
  }

  private async loadContent(windowStage: window.WindowStage): Promise<void> {
    await StorageService.init(this.context);
    await this.syncRuntimeState();
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        return;
      }

      NotificationService.requestEnable(this.context);
    });
  }

  private async syncRuntimeState(): Promise<void> {
    try {
      const state = await TimerService.restore();
      await ReminderService.syncWithTimer(state);
      await WidgetService.refreshAllForms();
      await this.syncKeepScreenOn(state.mode === 'focus' && state.status === 'running');
    } catch (error) {
      // Runtime recovery must be best-effort; the UI can still load and recover on the next tick.
      await ErrorLogService.record('runtime', `前台状态恢复失败：${error instanceof Error ? error.message : error}`);
    }
  }

  private async pauseFocusForBackground(reason: 'left_app' | 'app_terminated'): Promise<void> {
    try {
      const state = await TimerService.pauseForBackground(reason);
      await ReminderService.syncWithTimer(state);
      await WidgetService.refreshAllForms();
      await this.syncKeepScreenOn(false);
    } catch (error) {
      // Background transitions are best-effort; persisted timer state will be restored on next launch.
    }
  }

  private async syncKeepScreenOn(isOn: boolean): Promise<void> {
    if (!this.windowStage) {
      return;
    }

    try {
      const mainWindow = await this.windowStage.getMainWindow();
      await mainWindow.setWindowKeepScreenOn(isOn);
    } catch (error) {
      // Keep-screen is a best-effort focus guard and must not block normal app flow.
    }
  }
}
