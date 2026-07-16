import { findFocusTheme, FocusTheme, FOCUS_THEMES, isThemeUnlocked, unlockFocusTheme } from '../utils/focusThemeCore';
import { findFocusEffect, FocusEffect, FOCUS_EFFECTS, isEffectUnlocked, unlockFocusEffect } from '../utils/focusEffectCore';
import { timeCoinBalance } from '../utils/streakGuardCore';
import { SessionService } from './SessionService';
import { StorageService } from './StorageService';

export { FocusTheme, FOCUS_THEMES, FocusEffect, FOCUS_EFFECTS };

export interface ThemeListItem {
  theme: FocusTheme;
  unlocked: boolean;
  selected: boolean;
}

export interface EffectListItem {
  effect: FocusEffect;
  unlocked: boolean;
  selected: boolean;
}

export interface ThemeStoreSnapshot {
  items: ThemeListItem[];
  effectItems: EffectListItem[];
  activeTheme: FocusTheme;
  activeEffect: FocusEffect;
  coinBalance: number;
}

export interface UnlockOutcome {
  ok: boolean;
  message: string;
  snapshot: ThemeStoreSnapshot;
}

export class FocusThemeService {
  static async getActiveTheme(): Promise<FocusTheme> {
    const themeId = await StorageService.getFocusThemeId();
    const wallet = await StorageService.getStreakGuardWallet();
    // 数据被清除后选中主题可能失去解锁凭据，回退默认。
    if (!isThemeUnlocked(themeId, wallet)) {
      return findFocusTheme('default');
    }

    return findFocusTheme(themeId);
  }

  static async getActiveEffect(): Promise<FocusEffect> {
    const effectId = await StorageService.getFocusEffectId();
    const wallet = await StorageService.getStreakGuardWallet();
    if (!isEffectUnlocked(effectId, wallet)) {
      return findFocusEffect('ripple');
    }

    return findFocusEffect(effectId);
  }

  static async getSnapshot(): Promise<ThemeStoreSnapshot> {
    const sessions = await SessionService.listAll();
    const wallet = await StorageService.getStreakGuardWallet();
    const selectedId = await StorageService.getFocusThemeId();
    const selectedEffectId = await StorageService.getFocusEffectId();
    const activeTheme = await FocusThemeService.getActiveTheme();
    const activeEffect = await FocusThemeService.getActiveEffect();

    const items: ThemeListItem[] = FOCUS_THEMES.map((theme: FocusTheme): ThemeListItem => {
      return {
        theme,
        unlocked: isThemeUnlocked(theme.id, wallet),
        selected: theme.id === selectedId && isThemeUnlocked(selectedId, wallet)
      };
    });

    const effectItems: EffectListItem[] = FOCUS_EFFECTS.map((effect: FocusEffect): EffectListItem => {
      return {
        effect,
        unlocked: isEffectUnlocked(effect.id, wallet),
        selected: effect.id === selectedEffectId && isEffectUnlocked(selectedEffectId, wallet)
      };
    });

    return {
      items,
      effectItems,
      activeTheme,
      activeEffect,
      coinBalance: timeCoinBalance(sessions, wallet)
    };
  }

  static async unlockTheme(themeId: string): Promise<UnlockOutcome> {
    const sessions = await SessionService.listAll();
    const wallet = await StorageService.getStreakGuardWallet();
    const result = unlockFocusTheme(themeId, sessions, wallet, Date.now());
    if (result.ok) {
      await StorageService.saveStreakGuardWallet(result.wallet);
      await StorageService.saveFocusThemeId(themeId);
    }

    return {
      ok: result.ok,
      message: result.message,
      snapshot: await FocusThemeService.getSnapshot()
    };
  }

  static async selectTheme(themeId: string): Promise<UnlockOutcome> {
    const wallet = await StorageService.getStreakGuardWallet();
    if (!isThemeUnlocked(themeId, wallet)) {
      return {
        ok: false,
        message: '先解锁这个氛围',
        snapshot: await FocusThemeService.getSnapshot()
      };
    }

    await StorageService.saveFocusThemeId(themeId);
    return {
      ok: true,
      message: `已切换到「${findFocusTheme(themeId).title}」`,
      snapshot: await FocusThemeService.getSnapshot()
    };
  }

  static async unlockEffect(effectId: string): Promise<UnlockOutcome> {
    const sessions = await SessionService.listAll();
    const wallet = await StorageService.getStreakGuardWallet();
    const result = unlockFocusEffect(effectId, sessions, wallet, Date.now());
    if (result.ok) {
      await StorageService.saveStreakGuardWallet(result.wallet);
      await StorageService.saveFocusEffectId(effectId);
    }

    return {
      ok: result.ok,
      message: result.message,
      snapshot: await FocusThemeService.getSnapshot()
    };
  }

  static async selectEffect(effectId: string): Promise<UnlockOutcome> {
    const wallet = await StorageService.getStreakGuardWallet();
    if (!isEffectUnlocked(effectId, wallet)) {
      return {
        ok: false,
        message: '先解锁这个动效',
        snapshot: await FocusThemeService.getSnapshot()
      };
    }

    await StorageService.saveFocusEffectId(effectId);
    return {
      ok: true,
      message: `已切换到「${findFocusEffect(effectId).title}」`,
      snapshot: await FocusThemeService.getSnapshot()
    };
  }
}
