import reminderAgentManager from '@ohos.reminderAgentManager';
import { TimerMode, TimerState } from '../models/TimerState';
import { ErrorLogService } from './ErrorLogService';
import { ScheduledReminderState, StorageService } from './StorageService';

const BUNDLE_NAME = 'com.qishi.focus';
const ENTRY_ABILITY_NAME = 'EntryAbility';
const REMINDER_GROUP_ID = 'qishi.timer';
const REMINDER_NOTIFICATION_ID = 52024;

interface ReminderText {
  title: string;
  content: string;
  expiredContent: string;
}

function getReminderText(mode: TimerMode, taskTitle?: string): ReminderText {
  if (mode === 'break') {
    return {
      title: '可以回来了',
      content: '歇息结束，继续你的节奏',
      expiredContent: '歇息已经结束'
    };
  }

  const title = taskTitle ? taskTitle : '自由专注';
  return {
    title: '回来确认这一段',
    content: `${title} 到点了，回到栖时收束后才会计入完成`,
    expiredContent: '这一段需要回到 App 确认'
  };
}

function createReminderRecord(reminderId: number, state: TimerState): ScheduledReminderState {
  return {
    reminderId,
    timerId: state.id,
    expectedEndAt: state.expectedEndAt ? state.expectedEndAt : 0,
    mode: state.mode
  };
}

function isSameReminder(reminder: ScheduledReminderState, state: TimerState): boolean {
  return reminder.reminderId >= 0
    && reminder.timerId === state.id
    && reminder.expectedEndAt === (state.expectedEndAt ? state.expectedEndAt : 0)
    && reminder.mode === state.mode;
}

export class ReminderService {
  static async scheduleForTimer(state: TimerState): Promise<void> {
    const config = await StorageService.getConfig();
    if (!config.notificationEnabled || state.status !== 'running' || !state.expectedEndAt || !state.id) {
      await ReminderService.cancelCurrent();
      return;
    }

    const currentReminder = await StorageService.getScheduledReminder();
    if (isSameReminder(currentReminder, state)) {
      return;
    }

    const triggerSeconds = Math.max(1, Math.ceil((state.expectedEndAt - Date.now()) / 1000));
    const text = getReminderText(state.mode, state.taskTitle);
    const wantAgent: reminderAgentManager.WantAgent = {
      pkgName: BUNDLE_NAME,
      abilityName: ENTRY_ABILITY_NAME
    };
    const request: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: triggerSeconds,
      title: text.title,
      content: text.content,
      expiredContent: text.expiredContent,
      notificationId: REMINDER_NOTIFICATION_ID,
      groupId: REMINDER_GROUP_ID,
      tapDismissed: true,
      wantAgent
    };

    await ReminderService.cancelReminder(currentReminder);

    try {
      const reminderId = await reminderAgentManager.publishReminder(request);
      await StorageService.saveScheduledReminder(createReminderRecord(reminderId, state));
    } catch (error) {
      await StorageService.clearScheduledReminder();
      await ErrorLogService.record('reminder', `到点提醒创建失败：${error instanceof Error ? error.message : error}`);
    }
  }

  static async syncWithTimer(state: TimerState): Promise<void> {
    if (state.status === 'running') {
      await ReminderService.scheduleForTimer(state);
      return;
    }

    await ReminderService.cancelCurrent();
  }

  static async cancelCurrent(): Promise<void> {
    const reminder = await StorageService.getScheduledReminder();
    await ReminderService.cancelReminder(reminder);
  }

  private static async cancelReminder(reminder: ScheduledReminderState): Promise<void> {
    if (reminder.reminderId < 0) {
      return;
    }

    try {
      await reminderAgentManager.cancelReminder(reminder.reminderId);
    } catch (error) {
      // The reminder may already have fired or been removed by the system.
    }

    await StorageService.clearScheduledReminder();
  }

  static async cancelAll(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders();
    } catch (error) {
      // Clearing app data must not fail because the reminder subsystem is unavailable.
    }

    await StorageService.clearScheduledReminder();
  }
}
