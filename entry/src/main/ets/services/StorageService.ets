import dataPreferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { BillingSettings, defaultBillingSettings } from '../models/BillingSettings';
import { FocusSession } from '../models/FocusSession';
import { defaultPomodoroConfig, PomodoroConfig } from '../models/PomodoroConfig';
import { Task } from '../models/Task';
import { idleTimerState, TimerMode, TimerState } from '../models/TimerState';
import { ErrorLogEntry } from '../utils/errorLogCore';
import { PlanTemplate } from '../utils/planTemplateCore';
import { normalizeWallet, StreakGuardWallet } from '../utils/streakGuardCore';

const PREFERENCES_NAME = 'qishi_preferences';

interface StorageKeys {
  config: string;
  timerState: string;
  sessions: string;
  tasks: string;
  billingSettings: string;
  progress: string;
  widgetFormIds: string;
  scheduledReminder: string;
  errorLogs: string;
  customTemplates: string;
  streakGuardWallet: string;
}

const STORAGE_KEYS: StorageKeys = {
  config: 'qishi.config',
  timerState: 'qishi.timerState',
  sessions: 'qishi.sessions',
  tasks: 'qishi.tasks',
  billingSettings: 'qishi.billingSettings',
  progress: 'qishi.progress',
  widgetFormIds: 'qishi.widgetFormIds',
  scheduledReminder: 'qishi.scheduledReminder',
  errorLogs: 'qishi.errorLogs',
  customTemplates: 'qishi.customTemplates',
  streakGuardWallet: 'qishi.streakGuardWallet'
};

export interface PomodoroProgress {
  completedFocusRounds: number;
}

export interface WidgetFormIds {
  ids: string[];
}

export interface ScheduledReminderState {
  reminderId: number;
  timerId: string;
  expectedEndAt: number;
  mode: TimerMode;
}

const defaultPomodoroProgress: PomodoroProgress = {
  completedFocusRounds: 0
};

const defaultWidgetFormIds: WidgetFormIds = {
  ids: []
};

const defaultScheduledReminderState: ScheduledReminderState = {
  reminderId: -1,
  timerId: '',
  expectedEndAt: 0,
  mode: 'focus'
};

function cloneWidgetFormIds(formIds: WidgetFormIds): WidgetFormIds {
  return {
    ids: formIds.ids.slice()
  };
}

function cloneScheduledReminderState(state: ScheduledReminderState): ScheduledReminderState {
  return {
    reminderId: state.reminderId,
    timerId: state.timerId,
    expectedEndAt: state.expectedEndAt,
    mode: state.mode
  };
}

function normalizeConfig(config: PomodoroConfig): PomodoroConfig {
  return {
    focusMinutes: config.focusMinutes ? config.focusMinutes : defaultPomodoroConfig.focusMinutes,
    shortBreakMinutes: config.shortBreakMinutes ? config.shortBreakMinutes : defaultPomodoroConfig.shortBreakMinutes,
    longBreakMinutes: config.longBreakMinutes ? config.longBreakMinutes : defaultPomodoroConfig.longBreakMinutes,
    roundsBeforeLongBreak: config.roundsBeforeLongBreak
      ? config.roundsBeforeLongBreak
      : defaultPomodoroConfig.roundsBeforeLongBreak,
    dailyGoalMinutes: config.dailyGoalMinutes ? config.dailyGoalMinutes : defaultPomodoroConfig.dailyGoalMinutes,
    notificationEnabled: config.notificationEnabled === false ? false : defaultPomodoroConfig.notificationEnabled,
    vibrationEnabled: config.vibrationEnabled === false ? false : defaultPomodoroConfig.vibrationEnabled,
    soundEnabled: config.soundEnabled === false ? false : defaultPomodoroConfig.soundEnabled,
    focusGuardEnabled: true,
    debugQuickFocusEnabled: config.debugQuickFocusEnabled === true
  };
}

function normalizeBillingSettings(settings: BillingSettings): BillingSettings {
  const trimmedCurrencySymbol = settings.currencySymbol ? settings.currencySymbol.trim() : '';
  const trimmedInvoiceNote = settings.invoiceNote ? settings.invoiceNote.trim().slice(0, 100) : '';
  const excludedProjects = Array.isArray(settings.excludedProjects)
    ? settings.excludedProjects
      .map((projectName: string) => projectName ? projectName.trim() : '')
      .filter((projectName: string) => projectName.length > 0)
    : [];
  return {
    hourlyRate: settings.hourlyRate > 0 ? Math.min(9999, Math.floor(settings.hourlyRate)) : 0,
    minimumBillableMinutes: settings.minimumBillableMinutes > 0
      ? Math.min(240, Math.floor(settings.minimumBillableMinutes))
      : defaultBillingSettings.minimumBillableMinutes,
    roundingMinutes: settings.roundingMinutes > 0
      ? Math.min(120, Math.floor(settings.roundingMinutes))
      : defaultBillingSettings.roundingMinutes,
    currencySymbol: trimmedCurrencySymbol ? trimmedCurrencySymbol : defaultBillingSettings.currencySymbol,
    invoiceNote: trimmedInvoiceNote,
    excludedProjects
  };
}

export class StorageService {
  private static preferences?: dataPreferences.Preferences;

  static async init(context: common.Context): Promise<void> {
    if (StorageService.preferences) {
      return;
    }

    try {
      StorageService.preferences = await dataPreferences.getPreferences(context, PREFERENCES_NAME);
    } catch (error) {
      throw new Error('StorageService failed to initialize preferences.');
    }
  }

  private static getPreferences(): dataPreferences.Preferences {
    if (!StorageService.preferences) {
      throw new Error('StorageService.init(context) must be called before using storage.');
    }

    return StorageService.preferences;
  }

  private static readJson<T>(key: string, fallback: T): T {
    const preferences = StorageService.getPreferences();
    let rawValue = '';

    try {
      rawValue = preferences.getSync(key, '') as string;
    } catch (error) {
      return fallback;
    }

    if (!rawValue) {
      return fallback;
    }

    try {
      return JSON.parse(rawValue) as T;
    } catch (error) {
      return fallback;
    }
  }

  private static async writeJson<T>(key: string, value: T): Promise<void> {
    const preferences = StorageService.getPreferences();
    try {
      preferences.putSync(key, JSON.stringify(value));
      await preferences.flush();
    } catch (error) {
      // Persisting user state should fail softly; callers can continue using in-memory state.
    }
  }

  static async getConfig(): Promise<PomodoroConfig> {
    return normalizeConfig(StorageService.readJson<PomodoroConfig>(STORAGE_KEYS.config, defaultPomodoroConfig));
  }

  static async saveConfig(config: PomodoroConfig): Promise<void> {
    await StorageService.writeJson<PomodoroConfig>(STORAGE_KEYS.config, config);
  }

  static async getTimerState(): Promise<TimerState> {
    return StorageService.readJson<TimerState>(STORAGE_KEYS.timerState, idleTimerState);
  }

  static async saveTimerState(state: TimerState): Promise<void> {
    await StorageService.writeJson<TimerState>(STORAGE_KEYS.timerState, state);
  }

  static async clearTimerState(): Promise<void> {
    await StorageService.saveTimerState(idleTimerState);
  }

  static async getSessions(): Promise<FocusSession[]> {
    return StorageService.readJson<FocusSession[]>(STORAGE_KEYS.sessions, []);
  }

  static async saveSessions(sessions: FocusSession[]): Promise<void> {
    await StorageService.writeJson<FocusSession[]>(STORAGE_KEYS.sessions, sessions);
  }

  static async addSession(session: FocusSession): Promise<void> {
    const sessions = await StorageService.getSessions();
    sessions.unshift(session);
    await StorageService.saveSessions(sessions);
  }

  static async deleteSession(sessionId: string): Promise<void> {
    const sessions = await StorageService.getSessions();
    await StorageService.saveSessions(sessions.filter((session: FocusSession) => session.id !== sessionId));
  }

  static async clearSessions(): Promise<void> {
    await StorageService.saveSessions([]);
  }

  static async getTasks(): Promise<Task[]> {
    return StorageService.readJson<Task[]>(STORAGE_KEYS.tasks, []);
  }

  static async saveTasks(tasks: Task[]): Promise<void> {
    await StorageService.writeJson<Task[]>(STORAGE_KEYS.tasks, tasks);
  }

  static async getBillingSettings(): Promise<BillingSettings> {
    return normalizeBillingSettings(StorageService.readJson<BillingSettings>(
      STORAGE_KEYS.billingSettings,
      defaultBillingSettings
    ));
  }

  static async getErrorLogs(): Promise<ErrorLogEntry[]> {
    return StorageService.readJson<ErrorLogEntry[]>(STORAGE_KEYS.errorLogs, []);
  }

  static async saveErrorLogs(entries: ErrorLogEntry[]): Promise<void> {
    await StorageService.writeJson<ErrorLogEntry[]>(STORAGE_KEYS.errorLogs, entries);
  }

  static async getCustomTemplates(): Promise<PlanTemplate[]> {
    return StorageService.readJson<PlanTemplate[]>(STORAGE_KEYS.customTemplates, []);
  }

  static async saveCustomTemplates(templates: PlanTemplate[]): Promise<void> {
    await StorageService.writeJson<PlanTemplate[]>(STORAGE_KEYS.customTemplates, templates);
  }

  static async getStreakGuardWallet(): Promise<StreakGuardWallet> {
    return normalizeWallet(StorageService.readJson<StreakGuardWallet | undefined>(
      STORAGE_KEYS.streakGuardWallet,
      undefined
    ));
  }

  static async saveStreakGuardWallet(wallet: StreakGuardWallet): Promise<void> {
    await StorageService.writeJson<StreakGuardWallet>(STORAGE_KEYS.streakGuardWallet, wallet);
  }

  static async saveBillingSettings(settings: BillingSettings): Promise<void> {
    await StorageService.writeJson<BillingSettings>(
      STORAGE_KEYS.billingSettings,
      normalizeBillingSettings(settings)
    );
  }

  static async getProgress(): Promise<PomodoroProgress> {
    return StorageService.readJson<PomodoroProgress>(STORAGE_KEYS.progress, defaultPomodoroProgress);
  }

  static async saveProgress(progress: PomodoroProgress): Promise<void> {
    await StorageService.writeJson<PomodoroProgress>(STORAGE_KEYS.progress, progress);
  }

  static async getWidgetFormIds(): Promise<WidgetFormIds> {
    const formIds = StorageService.readJson<WidgetFormIds>(STORAGE_KEYS.widgetFormIds, defaultWidgetFormIds);
    return cloneWidgetFormIds(formIds);
  }

  static async saveWidgetFormIds(formIds: WidgetFormIds): Promise<void> {
    await StorageService.writeJson<WidgetFormIds>(STORAGE_KEYS.widgetFormIds, cloneWidgetFormIds(formIds));
  }

  static async getScheduledReminder(): Promise<ScheduledReminderState> {
    const reminder = StorageService.readJson<ScheduledReminderState>(
      STORAGE_KEYS.scheduledReminder,
      defaultScheduledReminderState
    );
    return cloneScheduledReminderState(reminder);
  }

  static async saveScheduledReminder(reminder: ScheduledReminderState): Promise<void> {
    await StorageService.writeJson<ScheduledReminderState>(
      STORAGE_KEYS.scheduledReminder,
      cloneScheduledReminderState(reminder)
    );
  }

  static async clearScheduledReminder(): Promise<void> {
    await StorageService.saveScheduledReminder(defaultScheduledReminderState);
  }

  static async clearAll(): Promise<void> {
    const preferences = StorageService.getPreferences();
    const widgetFormIds = await StorageService.getWidgetFormIds();
    try {
      preferences.clearSync();
      await preferences.flush();
    } catch (error) {
      // Keep the app usable even if the preference backend is temporarily unavailable.
    }
    await StorageService.saveWidgetFormIds(widgetFormIds);
  }
}
