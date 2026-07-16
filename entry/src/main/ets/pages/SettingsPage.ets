import { BillingSettings, BillingService, defaultBillingSettings } from '../services/BillingService';
import { defaultPomodoroConfig, PomodoroConfig } from '../models/PomodoroConfig';
import { ErrorLogEntry, ErrorLogService, errorSourceLabel } from '../services/ErrorLogService';
import { EffectListItem, FocusThemeService, ThemeListItem, ThemeStoreSnapshot } from '../services/FocusThemeService';
import { PRO_FEATURES, ProFeatureInfo, ProService, ProSnapshot } from '../services/ProService';
import { StreakGuardService } from '../services/StreakGuardService';
import { PromptService } from '../services/PromptService';
import { ReminderService } from '../services/ReminderService';
import { StorageService } from '../services/StorageService';
import { TimerService } from '../services/TimerService';
import { WidgetService } from '../services/WidgetService';

@Component
export struct SettingsPage {
  @State config: PomodoroConfig = {
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    roundsBeforeLongBreak: 4,
    dailyGoalMinutes: 120,
    notificationEnabled: true,
    vibrationEnabled: true,
    soundEnabled: true,
    focusGuardEnabled: true,
    debugQuickFocusEnabled: false
  };
  @State billingSettings: BillingSettings = defaultBillingSettings;
  @State errorLogs: ErrorLogEntry[] = [];
  @State showErrorLogs: boolean = false;
  @State proSnapshot: ProSnapshot = {
    active: false,
    statusText: '体验期 · 以下能力当前全部免费开放',
    badgeText: '体验期'
  };
  @State themeSnapshot: ThemeStoreSnapshot = {
    items: [],
    effectItems: [],
    activeTheme: {
      id: 'default',
      title: '晨雾',
      subtitle: '默认的安静浅色',
      price: 0,
      symbol: '☁',
      backgroundColor: '#F6F8F7',
      cardColor: '#FFFFFF',
      timerColor: '#1F2A2A',
      accentColor: '#5F9E8A'
    },
    activeEffect: {
      id: 'ripple',
      title: '涟漪',
      subtitle: '默认的一圈安静涟漪',
      price: 0,
      ringColors: ['#5F9E8A'],
      symbol: '✓',
      durationMs: 900
    },
    coinBalance: 0
  };

  aboutToAppear(): void {
    this.loadConfig();
  }

  private async loadConfig(): Promise<void> {
    this.config = await StorageService.getConfig();
    this.billingSettings = await BillingService.getSettings();
    this.themeSnapshot = await FocusThemeService.getSnapshot();
    this.proSnapshot = await ProService.getSnapshot();
    await this.loadErrorLogs();
  }

  private async unlockTheme(themeId: string): Promise<void> {
    const outcome = await FocusThemeService.unlockTheme(themeId);
    this.themeSnapshot = outcome.snapshot;
    PromptService.showToast(outcome.message);
  }

  private async selectTheme(themeId: string): Promise<void> {
    const outcome = await FocusThemeService.selectTheme(themeId);
    this.themeSnapshot = outcome.snapshot;
    PromptService.showToast(outcome.message);
  }

  private async unlockEffect(effectId: string): Promise<void> {
    const outcome = await FocusThemeService.unlockEffect(effectId);
    this.themeSnapshot = outcome.snapshot;
    PromptService.showToast(outcome.message);
  }

  private async selectEffect(effectId: string): Promise<void> {
    const outcome = await FocusThemeService.selectEffect(effectId);
    this.themeSnapshot = outcome.snapshot;
    PromptService.showToast(outcome.message);
  }

  private async debugTopUpCoins(): Promise<void> {
    await StreakGuardService.debugTopUpBalance(10000);
    this.themeSnapshot = await FocusThemeService.getSnapshot();
    PromptService.showToast(`时光币余额已补到 ${this.themeSnapshot.coinBalance}`);
  }

  private async loadErrorLogs(): Promise<void> {
    this.errorLogs = await ErrorLogService.listAll();
  }

  private errorTimeText(timestamp: number): string {
    const date = new Date(timestamp);
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const hours = `${date.getHours()}`.padStart(2, '0');
    const minutes = `${date.getMinutes()}`.padStart(2, '0');
    return `${month}/${day} ${hours}:${minutes}`;
  }

  private async clearErrorLogs(): Promise<void> {
    await ErrorLogService.clearAll();
    await this.loadErrorLogs();
    PromptService.showToast('异常日志已清空');
  }

  private async saveConfig(config: PomodoroConfig): Promise<void> {
    this.config = config;
    await StorageService.saveConfig(config);
    await WidgetService.refreshAllForms();
  }

  private createConfig(
    focusMinutes: number,
    shortBreakMinutes: number,
    longBreakMinutes: number,
    roundsBeforeLongBreak: number,
    dailyGoalMinutes: number,
    notificationEnabled: boolean,
    vibrationEnabled: boolean,
    soundEnabled: boolean,
    focusGuardEnabled: boolean,
    debugQuickFocusEnabled: boolean
  ): PomodoroConfig {
    return {
      focusMinutes,
      shortBreakMinutes,
      longBreakMinutes,
      roundsBeforeLongBreak,
      dailyGoalMinutes,
      notificationEnabled,
      vibrationEnabled,
      soundEnabled,
      focusGuardEnabled: true,
      debugQuickFocusEnabled
    };
  }

  private createBillingSettings(
    hourlyRate: number,
    minimumBillableMinutes: number,
    roundingMinutes: number
  ): BillingSettings {
    return {
      hourlyRate,
      minimumBillableMinutes,
      roundingMinutes,
      currencySymbol: this.billingSettings.currencySymbol,
      invoiceNote: this.billingSettings.invoiceNote,
      excludedProjects: this.billingSettings.excludedProjects
    };
  }

  private async saveBillingSettings(settings: BillingSettings): Promise<void> {
    this.billingSettings = settings;
    await BillingService.saveSettings(settings);
  }

  private async changeFocusMinutes(delta: number): Promise<void> {
    const nextMinutes = Math.min(120, Math.max(1, this.config.focusMinutes + delta));
    await this.saveConfig(this.createConfig(
      nextMinutes,
      this.config.shortBreakMinutes,
      this.config.longBreakMinutes,
      this.config.roundsBeforeLongBreak,
      this.config.dailyGoalMinutes,
      this.config.notificationEnabled,
      this.config.vibrationEnabled,
      this.config.soundEnabled,
      this.config.focusGuardEnabled,
      this.config.debugQuickFocusEnabled
    ));
  }

  private async changeShortBreakMinutes(delta: number): Promise<void> {
    const nextMinutes = Math.min(60, Math.max(1, this.config.shortBreakMinutes + delta));
    await this.saveConfig(this.createConfig(
      this.config.focusMinutes,
      nextMinutes,
      this.config.longBreakMinutes,
      this.config.roundsBeforeLongBreak,
      this.config.dailyGoalMinutes,
      this.config.notificationEnabled,
      this.config.vibrationEnabled,
      this.config.soundEnabled,
      this.config.focusGuardEnabled,
      this.config.debugQuickFocusEnabled
    ));
  }

  private async changeLongBreakMinutes(delta: number): Promise<void> {
    const nextMinutes = Math.min(120, Math.max(1, this.config.longBreakMinutes + delta));
    await this.saveConfig(this.createConfig(
      this.config.focusMinutes,
      this.config.shortBreakMinutes,
      nextMinutes,
      this.config.roundsBeforeLongBreak,
      this.config.dailyGoalMinutes,
      this.config.notificationEnabled,
      this.config.vibrationEnabled,
      this.config.soundEnabled,
      this.config.focusGuardEnabled,
      this.config.debugQuickFocusEnabled
    ));
  }

  private async changeRoundsBeforeLongBreak(delta: number): Promise<void> {
    const nextRounds = Math.min(12, Math.max(2, this.config.roundsBeforeLongBreak + delta));
    await this.saveConfig(this.createConfig(
      this.config.focusMinutes,
      this.config.shortBreakMinutes,
      this.config.longBreakMinutes,
      nextRounds,
      this.config.dailyGoalMinutes,
      this.config.notificationEnabled,
      this.config.vibrationEnabled,
      this.config.soundEnabled,
      this.config.focusGuardEnabled,
      this.config.debugQuickFocusEnabled
    ));
  }

  private async changeDailyGoalMinutes(delta: number): Promise<void> {
    const nextMinutes = Math.min(480, Math.max(15, this.config.dailyGoalMinutes + delta));
    await this.saveConfig(this.createConfig(
      this.config.focusMinutes,
      this.config.shortBreakMinutes,
      this.config.longBreakMinutes,
      this.config.roundsBeforeLongBreak,
      nextMinutes,
      this.config.notificationEnabled,
      this.config.vibrationEnabled,
      this.config.soundEnabled,
      this.config.focusGuardEnabled,
      this.config.debugQuickFocusEnabled
    ));
  }

  private async changeHourlyRate(delta: number): Promise<void> {
    const nextRate = Math.min(9999, Math.max(0, this.billingSettings.hourlyRate + delta));
    await this.saveBillingSettings(this.createBillingSettings(
      nextRate,
      this.billingSettings.minimumBillableMinutes,
      this.billingSettings.roundingMinutes
    ));
  }

  private async changeMinimumBillableMinutes(delta: number): Promise<void> {
    const nextMinutes = Math.min(240, Math.max(1, this.billingSettings.minimumBillableMinutes + delta));
    await this.saveBillingSettings(this.createBillingSettings(
      this.billingSettings.hourlyRate,
      nextMinutes,
      this.billingSettings.roundingMinutes
    ));
  }

  private async changeRoundingMinutes(delta: number): Promise<void> {
    const nextMinutes = Math.min(120, Math.max(1, this.billingSettings.roundingMinutes + delta));
    await this.saveBillingSettings(this.createBillingSettings(
      this.billingSettings.hourlyRate,
      this.billingSettings.minimumBillableMinutes,
      nextMinutes
    ));
  }

  private async updateInvoiceNote(note: string): Promise<void> {
    await this.saveBillingSettings({
      hourlyRate: this.billingSettings.hourlyRate,
      minimumBillableMinutes: this.billingSettings.minimumBillableMinutes,
      roundingMinutes: this.billingSettings.roundingMinutes,
      currencySymbol: this.billingSettings.currencySymbol,
      invoiceNote: note,
      excludedProjects: this.billingSettings.excludedProjects
    });
  }

  private async toggleNotification(isOn: boolean): Promise<void> {
    await this.saveConfig(this.createConfig(
      this.config.focusMinutes,
      this.config.shortBreakMinutes,
      this.config.longBreakMinutes,
      this.config.roundsBeforeLongBreak,
      this.config.dailyGoalMinutes,
      isOn,
      this.config.vibrationEnabled,
      this.config.soundEnabled,
      this.config.focusGuardEnabled,
      this.config.debugQuickFocusEnabled
    ));

    if (isOn) {
      await ReminderService.syncWithTimer(await TimerService.restore());
    } else {
      await ReminderService.cancelCurrent();
    }
  }

  private async toggleVibration(isOn: boolean): Promise<void> {
    await this.saveConfig(this.createConfig(
      this.config.focusMinutes,
      this.config.shortBreakMinutes,
      this.config.longBreakMinutes,
      this.config.roundsBeforeLongBreak,
      this.config.dailyGoalMinutes,
      this.config.notificationEnabled,
      isOn,
      this.config.soundEnabled,
      this.config.focusGuardEnabled,
      this.config.debugQuickFocusEnabled
    ));
  }

  private async toggleSound(isOn: boolean): Promise<void> {
    await this.saveConfig(this.createConfig(
      this.config.focusMinutes,
      this.config.shortBreakMinutes,
      this.config.longBreakMinutes,
      this.config.roundsBeforeLongBreak,
      this.config.dailyGoalMinutes,
      this.config.notificationEnabled,
      this.config.vibrationEnabled,
      isOn,
      this.config.focusGuardEnabled,
      this.config.debugQuickFocusEnabled
    ));
  }

  private async toggleQuickFocusDebug(isOn: boolean): Promise<void> {
    await this.saveConfig(this.createConfig(
      this.config.focusMinutes,
      this.config.shortBreakMinutes,
      this.config.longBreakMinutes,
      this.config.roundsBeforeLongBreak,
      this.config.dailyGoalMinutes,
      this.config.notificationEnabled,
      this.config.vibrationEnabled,
      this.config.soundEnabled,
      this.config.focusGuardEnabled,
      isOn
    ));
  }

  private async resetRhythm(): Promise<void> {
    const result = await PromptService.showDialog({
      title: '恢复默认节奏？',
      message: '专注、歇息和每日目标会恢复为栖时默认值，任务和记录会保留。',
      buttons: [
        {
          text: '取消',
          color: '#5F9E8A'
        },
        {
          text: '恢复',
          color: '#4D7EA8'
        }
      ]
    });

    if (result.index === 1) {
      await this.saveConfig(defaultPomodoroConfig);
      await ReminderService.syncWithTimer(await TimerService.restore());
      PromptService.showToast('已恢复默认节奏');
    }
  }

  private async resetBilling(): Promise<void> {
    await this.saveBillingSettings(defaultBillingSettings);
    PromptService.showToast('账单设置已恢复默认');
  }

  private async clearAll(): Promise<void> {
    const result = await PromptService.showDialog({
      title: '清除本地数据？',
      message: '任务、记录和当前计时状态都会被清除。',
      buttons: [
        {
          text: '取消',
          color: '#5F9E8A'
        },
        {
          text: '清除',
          color: '#C96F5D'
        }
      ]
    });

    if (result.index === 1) {
      await ReminderService.cancelAll();
      await StorageService.clearAll();
      await this.loadConfig();
      await WidgetService.refreshAllForms();
      PromptService.showToast('已清除');
    }
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Text('设置')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2A2A')
          .width('100%');

        Column({ space: 14 }) {
          Row() {
            Column({ space: 5 }) {
              Text('栖时 Pro')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1F2A2A');
              Text(this.proSnapshot.statusText)
                .fontSize(13)
                .fontColor('#5F9E8A');
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);

            Text(this.proSnapshot.badgeText)
              .fontSize(12)
              .fontColor('#FFFFFF')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor('#5F9E8A')
              .borderRadius(11);
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          ForEach(PRO_FEATURES, (feature: ProFeatureInfo) => {
            Row({ space: 12 }) {
              Text('✓')
                .fontSize(14)
                .fontColor('#5F9E8A');
              Column({ space: 3 }) {
                Text(feature.title)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1F2A2A')
                  .width('100%');
                Text(feature.description)
                  .fontSize(12)
                  .fontColor('#7B8785')
                  .width('100%');
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
            }
            .width('100%')
            .alignItems(VerticalAlign.Top);
          }, (feature: ProFeatureInfo) => feature.feature);

          if (!this.proSnapshot.active) {
            Text('订阅上线后，已有的记录和导出不受影响；体验期产生的数据始终保留在你的设备本地。')
              .fontSize(11)
              .fontColor('#7B8785')
              .width('100%')
              .padding(10)
              .backgroundColor('#F6F8F7')
              .borderRadius(12);
          }
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
        .border({
          width: 1,
          color: '#DDE8EA'
        });

        Column({ space: 14 }) {
          Row() {
            Column({ space: 4 }) {
              Text('专注氛围')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1F2A2A');
              Text('用时光币解锁专注中的配色')
                .fontSize(12)
                .fontColor('#7B8785');
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);

            Text(`余额 ${this.themeSnapshot.coinBalance}`)
              .fontSize(12)
              .fontColor('#4D7EA8')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor('#EAF2F8')
              .borderRadius(11);

            if (this.config.debugQuickFocusEnabled) {
              Button('补到 1 万')
                .height(28)
                .fontSize(11)
                .fontColor('#C96F5D')
                .backgroundColor('#FFF8F6')
                .borderRadius(10)
                .margin({ left: 8 })
                .onClick(() => {
                  this.debugTopUpCoins();
                });
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          ForEach(this.themeSnapshot.items, (item: ThemeListItem) => {
            Row({ space: 12 }) {
              Stack({ alignContent: Alignment.Center }) {
                Column()
                  .width(34)
                  .height(34)
                  .backgroundColor(item.theme.backgroundColor)
                  .borderRadius(10)
                  .border({
                    width: 2,
                    color: item.theme.accentColor
                  });

                Text(item.theme.symbol)
                  .fontSize(15)
                  .fontColor(item.theme.accentColor);
              }
              .width(34)
              .height(34);

              Column({ space: 3 }) {
                Text(item.theme.title)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1F2A2A');
                Text(item.theme.subtitle)
                  .fontSize(11)
                  .fontColor('#7B8785')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1);

              if (item.selected) {
                Text('使用中')
                  .fontSize(12)
                  .fontColor('#5F9E8A')
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor('#EAF3F0')
                  .borderRadius(11);
              } else if (item.unlocked) {
                Button('使用')
                  .height(32)
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#5F9E8A')
                  .borderRadius(11)
                  .onClick(() => {
                    this.selectTheme(item.theme.id);
                  });
              } else {
                Button(`${item.theme.price} 币`)
                  .height(32)
                  .fontSize(12)
                  .fontColor(this.themeSnapshot.coinBalance >= item.theme.price ? '#FFFFFF' : '#9AA6A3')
                  .backgroundColor(this.themeSnapshot.coinBalance >= item.theme.price ? '#4D7EA8' : '#EEF3F2')
                  .borderRadius(11)
                  .enabled(this.themeSnapshot.coinBalance >= item.theme.price)
                  .onClick(() => {
                    this.unlockTheme(item.theme.id);
                  });
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center);
          }, (item: ThemeListItem) => `${item.theme.id}_${item.unlocked}_${item.selected}`);

          Text('氛围只改变专注进行中的配色，完成后回到日常界面。')
            .fontSize(11)
            .fontColor('#7B8785')
            .width('100%');

          Divider()
            .color('#EEF3F2');

          Text('完成动效')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2A2A')
            .width('100%');

          ForEach(this.themeSnapshot.effectItems, (item: EffectListItem) => {
            Row({ space: 12 }) {
              Text(item.effect.symbol)
                .fontSize(20)
                .fontColor(item.effect.ringColors[0])
                .width(34)
                .textAlign(TextAlign.Center);

              Column({ space: 3 }) {
                Text(item.effect.title)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1F2A2A');
                Text(item.effect.subtitle)
                  .fontSize(11)
                  .fontColor('#7B8785')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1);

              if (item.selected) {
                Text('使用中')
                  .fontSize(12)
                  .fontColor('#5F9E8A')
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor('#EAF3F0')
                  .borderRadius(11);
              } else if (item.unlocked) {
                Button('使用')
                  .height(32)
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#5F9E8A')
                  .borderRadius(11)
                  .onClick(() => {
                    this.selectEffect(item.effect.id);
                  });
              } else {
                Button(`${item.effect.price} 币`)
                  .height(32)
                  .fontSize(12)
                  .fontColor(this.themeSnapshot.coinBalance >= item.effect.price ? '#FFFFFF' : '#9AA6A3')
                  .backgroundColor(this.themeSnapshot.coinBalance >= item.effect.price ? '#4D7EA8' : '#EEF3F2')
                  .borderRadius(11)
                  .enabled(this.themeSnapshot.coinBalance >= item.effect.price)
                  .onClick(() => {
                    this.unlockEffect(item.effect.id);
                  });
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center);
          }, (item: EffectListItem) => `${item.effect.id}_${item.unlocked}_${item.selected}`);

          Text('动效在每段专注完成时播放一次。')
            .fontSize(11)
            .fontColor('#7B8785')
            .width('100%');
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
        .border({
          width: 1,
          color: '#DDE8EA'
        });

        Column({ space: 16 }) {
          Row() {
            Text('客户账单')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1F2A2A')
              .layoutWeight(1);

            Button('默认')
              .height(32)
              .fontSize(12)
              .fontColor('#4D7EA8')
              .backgroundColor('#EAF2F8')
              .borderRadius(11)
              .onClick(() => {
                this.resetBilling();
              });
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          Row() {
            Text('小时费率')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .layoutWeight(1);
            Button('-')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#1F2A2A')
              .backgroundColor('#DDE8EA')
              .borderRadius(18)
              .onClick(() => {
                this.changeHourlyRate(-20);
              });
            Text(`${this.billingSettings.currencySymbol}${this.billingSettings.hourlyRate}`)
              .fontSize(15)
              .fontColor('#1F2A2A')
              .width(86)
              .textAlign(TextAlign.Center);
            Button('+')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#FFFFFF')
              .backgroundColor('#5F9E8A')
              .borderRadius(18)
              .onClick(() => {
                this.changeHourlyRate(20);
              });
          }
          .width('100%');

          Row() {
            Text('最小计费')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .layoutWeight(1);
            Button('-')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#1F2A2A')
              .backgroundColor('#DDE8EA')
              .borderRadius(18)
              .onClick(() => {
                this.changeMinimumBillableMinutes(-5);
              });
            Text(`${this.billingSettings.minimumBillableMinutes} 分钟`)
              .fontSize(15)
              .fontColor('#1F2A2A')
              .width(86)
              .textAlign(TextAlign.Center);
            Button('+')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#FFFFFF')
              .backgroundColor('#5F9E8A')
              .borderRadius(18)
              .onClick(() => {
                this.changeMinimumBillableMinutes(5);
              });
          }
          .width('100%');

          Row() {
            Text('取整粒度')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .layoutWeight(1);
            Button('-')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#1F2A2A')
              .backgroundColor('#DDE8EA')
              .borderRadius(18)
              .onClick(() => {
                this.changeRoundingMinutes(-5);
              });
            Text(`${this.billingSettings.roundingMinutes} 分钟`)
              .fontSize(15)
              .fontColor('#1F2A2A')
              .width(86)
              .textAlign(TextAlign.Center);
            Button('+')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#FFFFFF')
              .backgroundColor('#5F9E8A')
              .borderRadius(18)
              .onClick(() => {
                this.changeRoundingMinutes(5);
              });
          }
          .width('100%');

          Column({ space: 8 }) {
            Text('发票备注')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .width('100%');
            TextInput({ placeholder: '例如：含 6 月项目开发工时', text: this.billingSettings.invoiceNote })
              .height(42)
              .fontSize(13)
              .backgroundColor('#F6F8F7')
              .borderRadius(12)
              .maxLength(100)
              .onChange((value: string) => {
                this.updateInvoiceNote(value);
              });
            Text('备注会出现在账单卡片和导出的账单 CSV 中。')
              .fontSize(11)
              .fontColor('#7B8785')
              .width('100%');
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
        .border({
          width: 1,
          color: '#DDE8EA'
        });

        Column({ space: 16 }) {
          Text('专注节奏')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2A2A')
            .width('100%');

          Row() {
            Text('专注时长')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .layoutWeight(1);
            Button('-')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#1F2A2A')
              .backgroundColor('#DDE8EA')
              .borderRadius(18)
              .onClick(() => {
                this.changeFocusMinutes(-5);
              });
            Text(`${this.config.focusMinutes} 分钟`)
              .fontSize(15)
              .fontColor('#1F2A2A')
              .width(86)
              .textAlign(TextAlign.Center);
            Button('+')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#FFFFFF')
              .backgroundColor('#5F9E8A')
              .borderRadius(18)
              .onClick(() => {
                this.changeFocusMinutes(5);
              });
          }
          .width('100%');

          Row() {
            Text('短歇息')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .layoutWeight(1);
            Button('-')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#1F2A2A')
              .backgroundColor('#DDE8EA')
              .borderRadius(18)
              .onClick(() => {
                this.changeShortBreakMinutes(-1);
              });
            Text(`${this.config.shortBreakMinutes} 分钟`)
              .fontSize(15)
              .fontColor('#1F2A2A')
              .width(86)
              .textAlign(TextAlign.Center);
            Button('+')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#FFFFFF')
              .backgroundColor('#5F9E8A')
              .borderRadius(18)
              .onClick(() => {
                this.changeShortBreakMinutes(1);
              });
          }
          .width('100%');

          Row() {
            Text('长歇息')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .layoutWeight(1);
            Button('-')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#1F2A2A')
              .backgroundColor('#DDE8EA')
              .borderRadius(18)
              .onClick(() => {
                this.changeLongBreakMinutes(-5);
              });
            Text(`${this.config.longBreakMinutes} 分钟`)
              .fontSize(15)
              .fontColor('#1F2A2A')
              .width(86)
              .textAlign(TextAlign.Center);
            Button('+')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#FFFFFF')
              .backgroundColor('#5F9E8A')
              .borderRadius(18)
              .onClick(() => {
                this.changeLongBreakMinutes(5);
              });
          }
          .width('100%');

          Row() {
            Text('长歇息间隔')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .layoutWeight(1);
            Button('-')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#1F2A2A')
              .backgroundColor('#DDE8EA')
              .borderRadius(18)
              .onClick(() => {
                this.changeRoundsBeforeLongBreak(-1);
              });
            Text(`${this.config.roundsBeforeLongBreak} 次`)
              .fontSize(15)
              .fontColor('#1F2A2A')
              .width(86)
              .textAlign(TextAlign.Center);
            Button('+')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#FFFFFF')
              .backgroundColor('#5F9E8A')
              .borderRadius(18)
              .onClick(() => {
                this.changeRoundsBeforeLongBreak(1);
              });
          }
          .width('100%');

          Row() {
            Text('每日目标')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .layoutWeight(1);
            Button('-')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#1F2A2A')
              .backgroundColor('#DDE8EA')
              .borderRadius(18)
              .onClick(() => {
                this.changeDailyGoalMinutes(-15);
              });
            Text(`${this.config.dailyGoalMinutes} 分钟`)
              .fontSize(15)
              .fontColor('#1F2A2A')
              .width(86)
              .textAlign(TextAlign.Center);
            Button('+')
              .width(36)
              .height(36)
              .fontSize(20)
              .fontColor('#FFFFFF')
              .backgroundColor('#5F9E8A')
              .borderRadius(18)
              .onClick(() => {
                this.changeDailyGoalMinutes(15);
              });
          }
          .width('100%');
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
        .border({
          width: 1,
          color: '#DDE8EA'
        });

        Column({ space: 12 }) {
          Text('提醒')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2A2A')
            .width('100%');

          Row() {
            Text('专注结束提醒')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .layoutWeight(1);
            Toggle({ type: ToggleType.Switch, isOn: this.config.notificationEnabled })
              .selectedColor('#5F9E8A')
              .onChange((isOn: boolean) => {
                this.toggleNotification(isOn);
              });
          }
          .width('100%');

          Row() {
            Text('震动提醒')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .layoutWeight(1);
            Toggle({ type: ToggleType.Switch, isOn: this.config.vibrationEnabled })
              .selectedColor('#5F9E8A')
              .onChange((isOn: boolean) => {
                this.toggleVibration(isOn);
              });
          }
          .width('100%');

          Row() {
            Text('提示音')
              .fontSize(15)
              .fontColor('#1F2A2A')
              .layoutWeight(1);
            Toggle({ type: ToggleType.Switch, isOn: this.config.soundEnabled })
              .selectedColor('#5F9E8A')
              .onChange((isOn: boolean) => {
                this.toggleSound(isOn);
              });
          }
          .width('100%');
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
          .border({
            width: 1,
            color: '#DDE8EA'
          });

        Column({ space: 12 }) {
          Text('专注守门')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2A2A')
            .width('100%');

          Row() {
            Column({ space: 3 }) {
              Text('离开 App 不可结算')
                .fontSize(15)
                .fontColor('#1F2A2A');
              Text('专注期间只允许栖时前台；切走或杀后台会写入违规记录')
                .fontSize(12)
                .fontColor('#7B8785');
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);

            Text('已开启')
              .fontSize(13)
              .fontColor('#FFFFFF')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#5F9E8A')
              .borderRadius(12);
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
        .border({
          width: 1,
          color: '#DDE8EA'
        });

        Column({ space: 12 }) {
          Text('开发调试')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2A2A')
            .width('100%');

          Row() {
            Column({ space: 3 }) {
              Text('显示 10 秒快速验证')
                .fontSize(15)
                .fontColor('#1F2A2A');
              Text('仅用于真机调试计时结束流程')
                .fontSize(12)
                .fontColor('#7B8785');
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);

            Toggle({ type: ToggleType.Switch, isOn: this.config.debugQuickFocusEnabled })
              .selectedColor('#5F9E8A')
              .onChange((isOn: boolean) => {
                this.toggleQuickFocusDebug(isOn);
              });
          }
          .width('100%');

          Row() {
            Column({ space: 3 }) {
              Text('异常日志')
                .fontSize(15)
                .fontColor('#1F2A2A');
              Text(this.errorLogs.length > 0 ? `最近 ${this.errorLogs.length} 条提醒/存储/卡片异常` : '暂无异常记录')
                .fontSize(12)
                .fontColor('#7B8785');
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);

            Toggle({ type: ToggleType.Switch, isOn: this.showErrorLogs })
              .selectedColor('#5F9E8A')
              .onChange((isOn: boolean) => {
                this.showErrorLogs = isOn;
                if (isOn) {
                  this.loadErrorLogs();
                }
              });
          }
          .width('100%');

          if (this.showErrorLogs) {
            if (this.errorLogs.length === 0) {
              Text('提醒失败、存储失败和卡片刷新失败会记录在这里，用于排查真机问题。')
                .fontSize(12)
                .fontColor('#7B8785')
                .width('100%')
                .padding(10)
                .backgroundColor('#F6F8F7')
                .borderRadius(12);
            } else {
              Column({ space: 8 }) {
                ForEach(this.errorLogs.slice(0, 10), (entry: ErrorLogEntry) => {
                  Column({ space: 3 }) {
                    Row() {
                      Text(errorSourceLabel(entry.source))
                        .fontSize(11)
                        .fontColor('#C96F5D')
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .backgroundColor('#FFF0EC')
                        .borderRadius(9);
                      Text(this.errorTimeText(entry.at))
                        .fontSize(11)
                        .fontColor('#9AA6A3')
                        .layoutWeight(1)
                        .textAlign(TextAlign.End);
                    }
                    .width('100%');

                    Text(entry.message)
                      .fontSize(12)
                      .fontColor('#1F2A2A')
                      .width('100%')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
                  .width('100%')
                  .padding(10)
                  .backgroundColor('#F6F8F7')
                  .borderRadius(12)
                  .alignItems(HorizontalAlign.Start);
                }, (entry: ErrorLogEntry) => `${entry.at}-${entry.source}`);

                Button('清空异常日志')
                  .height(36)
                  .width('100%')
                  .fontSize(13)
                  .fontColor('#C96F5D')
                  .backgroundColor('#FFF0EC')
                  .borderRadius(12)
                  .onClick(() => {
                    this.clearErrorLogs();
                  });
              }
              .width('100%');
            }
          }
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
        .border({
          width: 1,
          color: '#DDE8EA'
        });

        Button('恢复默认节奏')
          .height(48)
          .width('100%')
          .fontSize(15)
          .fontColor('#4D7EA8')
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .border({
            width: 1,
            color: '#DDE8EA'
          })
          .onClick(() => {
            this.resetRhythm();
          });

        Button('清除本地数据')
          .height(50)
          .width('100%')
          .fontSize(16)
          .fontColor('#C96F5D')
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .border({
            width: 1,
            color: '#E8D3CE'
          })
          .onClick(() => {
            this.clearAll();
          });
      }
      .width('100%')
      .padding(20);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F8F7');
  }
}
