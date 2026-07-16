import { findFocusTheme, FocusTheme, FOCUS_THEMES, isThemeUnlocked, unlockFocusTheme } from '../utils/focusThemeCore';
import { timeCoinBalance } from '../utils/streakGuardCore';
import { SessionService } from './SessionService';
import { StorageService } from './StorageService';

export { FocusTheme, FOCUS_THEMES };

export interface ThemeListItem {
  theme: FocusTheme;
  unlocked: boolean;
  selected: boolean;
}

export interface ThemeStoreSnapshot {
  items: ThemeListItem[];
  activeTheme: FocusTheme;
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

  static async getSnapshot(): Promise<ThemeStoreSnapshot> {
    const sessions = await SessionService.listAll();
    const wallet = await StorageService.getStreakGuardWallet();
    const selectedId = await StorageService.getFocusThemeId();
    const activeTheme = await FocusThemeService.getActiveTheme();

    const items: ThemeListItem[] = FOCUS_THEMES.map((theme: FocusTheme): ThemeListItem => {
      return {
        theme,
        unlocked: isThemeUnlocked(theme.id, wallet),
        selected: theme.id === selectedId && isThemeUnlocked(selectedId, wallet)
      };
    });

    return {
      items,
      activeTheme,
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
}
