import { DT } from '../utils/designTokens';

export type AppButtonVariant = 'primary' | 'info' | 'danger' | 'soft' | 'softInfo' | 'softDanger' | 'ghost';
export type AppButtonSize = 's' | 'm' | 'l';

// 统一按钮：微渐变 + 品牌色投影 + 按压缩放反馈。
// primary/info/danger 为实色渐变白字；soft* 为浅底彩字；ghost 为中性浅底。
@Component
export struct AppButton {
  @Prop title: string = '';
  @Prop variant: AppButtonVariant = 'primary';
  @Prop buttonSize: AppButtonSize = 'l';
  @Prop buttonEnabled: boolean = true;
  @Prop stretch: boolean = true;
  onTap?: () => void;

  private heightFor(): number {
    if (this.buttonSize === 's') {
      return DT.buttonS;
    }
    if (this.buttonSize === 'm') {
      return DT.buttonM;
    }
    return DT.buttonL;
  }

  private radiusFor(): number {
    return this.buttonSize === 's' ? DT.radiusS : DT.radiusM;
  }

  private fontSizeFor(): number {
    if (this.buttonSize === 's') {
      return DT.fontBody2;
    }
    if (this.buttonSize === 'm') {
      return DT.fontBody;
    }
    return DT.fontTitle;
  }

  private isSolid(): boolean {
    return this.variant === 'primary' || this.variant === 'info' || this.variant === 'danger';
  }

  private gradientColors(): Array<[string, number]> {
    if (!this.buttonEnabled) {
      return [[DT.disabledBg, 0], [DT.disabledBg, 1]];
    }
    if (this.variant === 'primary') {
      return [[DT.brandLight, 0], [DT.brandDeep, 1]];
    }
    if (this.variant === 'info') {
      return [[DT.infoLight, 0], [DT.infoDeep, 1]];
    }
    if (this.variant === 'danger') {
      return [[DT.dangerLight, 0], [DT.dangerDeep, 1]];
    }
    if (this.variant === 'soft') {
      return [[DT.bgBrandSoft, 0], [DT.bgBrandSoft, 1]];
    }
    if (this.variant === 'softInfo') {
      return [[DT.bgInfoSoft, 0], [DT.bgInfoSoft, 1]];
    }
    if (this.variant === 'softDanger') {
      return [[DT.bgDangerSoft, 0], [DT.bgDangerSoft, 1]];
    }
    return [[DT.bgNeutralSoft, 0], [DT.bgNeutralSoft, 1]];
  }

  private textColor(): string {
    if (!this.buttonEnabled) {
      return DT.textPlaceholder;
    }
    if (this.isSolid()) {
      return '#FFFFFF';
    }
    if (this.variant === 'soft') {
      return DT.brandDeep;
    }
    if (this.variant === 'softInfo') {
      return DT.infoDeep;
    }
    if (this.variant === 'softDanger') {
      return DT.dangerDeep;
    }
    return DT.textSecondary;
  }

  private shadowFor(): ShadowOptions {
    if (!this.buttonEnabled || !this.isSolid()) {
      return DT.shadowNone;
    }
    if (this.variant === 'primary') {
      return DT.shadowButton;
    }
    if (this.variant === 'info') {
      return { radius: 10, color: '#2E4D7EA8', offsetX: 0, offsetY: 4 };
    }
    return { radius: 10, color: '#2EC96F5D', offsetX: 0, offsetY: 4 };
  }

  build() {
    Button(this.title)
      .width(this.stretch ? '100%' : 'auto')
      .height(this.heightFor())
      .fontSize(this.fontSizeFor())
      .fontWeight(FontWeight.Medium)
      .fontColor(this.textColor())
      .padding(this.stretch ? { left: 0, right: 0 } : { left: 16, right: 16 })
      .linearGradient({
        angle: 180,
        colors: this.gradientColors()
      })
      .animation({ duration: DT.durFast, curve: Curve.EaseInOut })
      .borderRadius(this.radiusFor())
      .shadow(this.shadowFor())
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
      .enabled(this.buttonEnabled)
      .onClick(() => {
        if (this.onTap) {
          this.onTap();
        }
      });
  }
}
