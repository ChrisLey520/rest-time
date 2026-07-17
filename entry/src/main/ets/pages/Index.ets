import { FocusPage } from './FocusPage';
import { RecordPage } from './RecordPage';
import { SettingsPage } from './SettingsPage';
import { TaskPage } from './TaskPage';
import { AppStateService } from '../services/AppStateService';
import { PromptService } from '../services/PromptService';
import { DT } from '../utils/designTokens';

interface TabItemMeta {
  label: string;
}

const TAB_ITEMS: TabItemMeta[] = [
  { label: '专注' },
  { label: '任务' },
  { label: '记录' },
  { label: '设置' }
];

@Entry
@Component
struct Index {
  @State selectedIndex: number = 0;
  @State pageBackgroundColor: string = DT.bgPage;
  @State barBackgroundColor: string = '#FFFFFF';
  @State barAccentColor: string = DT.brand;
  private tabsController: TabsController = new TabsController();
  private ticker: number = -1;

  aboutToAppear(): void {
    PromptService.bindContext(this.getUIContext());
    this.startTicker();
  }

  aboutToDisappear(): void {
    this.stopTicker();
  }

  private startTicker(): void {
    this.stopTicker();
    this.ticker = setInterval(() => {
      const nextIndex = AppStateService.getSelectedTabIndex();
      if (this.selectedIndex !== nextIndex) {
        this.selectedIndex = nextIndex;
        this.tabsController.changeIndex(nextIndex);
      }

      // 专注进行中让 Tabs 背景和底部栏跟随主题，避免深色主题下白色断层。
      const themeBar = AppStateService.getThemeBar();
      if (this.pageBackgroundColor !== themeBar.backgroundColor) {
        this.pageBackgroundColor = themeBar.backgroundColor;
      }
      if (this.barBackgroundColor !== themeBar.barColor) {
        this.barBackgroundColor = themeBar.barColor;
      }
      if (this.barAccentColor !== themeBar.accentColor) {
        this.barAccentColor = themeBar.accentColor;
      }
    }, 200);
  }

  private stopTicker(): void {
    if (this.ticker !== -1) {
      clearInterval(this.ticker);
      this.ticker = -1;
    }
  }

  // 深色主题底栏上未选中项用浅灰，浅色底沿用次级文字色。
  private isDarkBar(): boolean {
    const raw = this.barBackgroundColor.startsWith('#')
      ? this.barBackgroundColor.substring(1)
      : this.barBackgroundColor;
    if (raw.length !== 6) {
      return false;
    }
    const r = parseInt(raw.substring(0, 2), 16);
    const g = parseInt(raw.substring(2, 4), 16);
    const b = parseInt(raw.substring(4, 6), 16);
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255 < 0.5;
  }

  // 选中态跟随专注主题的 accentColor；日常浅色为品牌绿。
  private tabActiveColor(): string {
    return this.barAccentColor;
  }

  private tabInactiveColor(): string {
    return this.isDarkBar() ? '#8A9490' : DT.textPlaceholder;
  }

  // 系统 SymbolGlyph 矢量符号：线性绘制风格，可随选中态着色并播放弹跳动效。
  private tabSymbol(index: number): Resource {
    if (index === 0) {
      return $r('sys.symbol.timer');
    }
    if (index === 1) {
      return $r('sys.symbol.checkmark_square');
    }
    if (index === 2) {
      return $r('sys.symbol.histogram');
    }
    return $r('sys.symbol.gearshape');
  }

  @Builder
  tabItem(index: number) {
    Column({ space: 3 }) {
      // 选中指示条：随选中态渐显。
      Row()
        .width(20)
        .height(3)
        .backgroundColor(this.selectedIndex === index ? this.tabActiveColor() : DT.transparent)
        .animation({ duration: DT.durFast, curve: Curve.EaseInOut })
        .borderRadius(2);
      SymbolGlyph(this.tabSymbol(index))
        .fontSize(22)
        .fontColor([this.selectedIndex === index ? this.tabActiveColor() : this.tabInactiveColor()])
        .fontWeight(this.selectedIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.UP), this.selectedIndex === index);
      Text(TAB_ITEMS[index].label)
        .fontSize(DT.fontCaption)
        .fontWeight(this.selectedIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selectedIndex === index ? this.tabActiveColor() : this.tabInactiveColor())
        .animation({ duration: DT.durFast, curve: Curve.EaseInOut });
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center);
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.selectedIndex, controller: this.tabsController }) {
      TabContent() {
        FocusPage();
      }
      .tabBar(this.tabItem(0));

      TabContent() {
        TaskPage();
      }
      .tabBar(this.tabItem(1));

      TabContent() {
        RecordPage();
      }
      .tabBar(this.tabItem(2));

      TabContent() {
        SettingsPage();
      }
      .tabBar(this.tabItem(3));
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackgroundColor)
    .barBackgroundColor(this.barBackgroundColor)
    .animation({ duration: DT.durSlow, curve: Curve.EaseInOut })
    .barMode(BarMode.Fixed)
    .animationDuration(240)
    .onChange((index: number) => {
      this.selectedIndex = index;
      AppStateService.setSelectedTabIndex(index);
    });
  }
}
