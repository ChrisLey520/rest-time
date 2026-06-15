import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { NotificationService } from '../services/NotificationService';
import { ReminderService } from '../services/ReminderService';
import { StorageService } from '../services/StorageService';
import { TimerService } from '../services/TimerService';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.loadContent(windowStage);
  }

  private async loadContent(windowStage: window.WindowStage): Promise<void> {
    await StorageService.init(this.context);
    const state = await TimerService.restore();
    await ReminderService.syncWithTimer(state);
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        return;
      }

      NotificationService.requestEnable(this.context);
    });
  }
}
