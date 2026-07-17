import { DT } from '../utils/designTokens';

// 设置页步进行：标签 + −/数值/+，按钮统一圆形并带按压反馈。
@Component
export struct StepperRow {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop minusEnabled: boolean = true;
  @Prop plusEnabled: boolean = true;
  onMinus?: () => void;
  onPlus?: () => void;

  build() {
    Row() {
      Text(this.label)
        .fontSize(DT.fontBody)
        .fontColor(DT.textPrimary)
        .layoutWeight(1);

      Button('−')
        .width(36)
        .height(36)
        .fontSize(18)
        .fontColor(this.minusEnabled ? DT.textPrimary : DT.textPlaceholder)
        .backgroundColor(this.minusEnabled ? DT.bgNeutralSoft : DT.disabledBg)
        .borderRadius(18)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .enabled(this.minusEnabled)
        .onClick(() => {
          if (this.onMinus) {
            this.onMinus();
          }
        });

      Text(this.value)
        .fontSize(DT.fontBody)
        .fontWeight(FontWeight.Medium)
        .fontColor(DT.textPrimary)
        .width(86)
        .textAlign(TextAlign.Center);

      Button('+')
        .width(36)
        .height(36)
        .fontSize(18)
        .fontColor('#FFFFFF')
        .linearGradient({
          angle: 180,
          colors: this.plusEnabled
            ? [[DT.brandLight, 0], [DT.brandDeep, 1]]
            : [[DT.disabledBg, 0], [DT.disabledBg, 1]]
        })
        .borderRadius(18)
        .shadow(this.plusEnabled ? DT.shadowButton : DT.shadowNone)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .enabled(this.plusEnabled)
        .onClick(() => {
          if (this.onPlus) {
            this.onPlus();
          }
        });
    }
    .width('100%');
  }
}
