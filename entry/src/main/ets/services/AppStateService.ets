export interface AppThemeBar {
  // 专注进行中时的主题条：Tabs 背景与内容底色跟随;null 表示日常浅色。
  backgroundColor: string;
  barColor: string;
  active: boolean;
}

const defaultThemeBar: AppThemeBar = {
  backgroundColor: '#F6F8F7',
  barColor: '#FFFFFF',
  active: false
};

export class AppStateService {
  private static selectedTabIndex: number = 0;
  private static themeBar: AppThemeBar = defaultThemeBar;

  static getSelectedTabIndex(): number {
    return AppStateService.selectedTabIndex;
  }

  static setSelectedTabIndex(index: number): void {
    AppStateService.selectedTabIndex = index;
  }

  static getThemeBar(): AppThemeBar {
    return AppStateService.themeBar;
  }

  /** 专注进行中由 FocusPage 发布主题条；结束时恢复默认。 */
  static setThemeBar(backgroundColor: string, barColor: string): void {
    AppStateService.themeBar = {
      backgroundColor,
      barColor,
      active: true
    };
  }

  static clearThemeBar(): void {
    AppStateService.themeBar = defaultThemeBar;
  }
}
