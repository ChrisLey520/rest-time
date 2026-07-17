import { DT } from '../utils/designTokens';

// 统一状态胶囊：浅色底 + 彩字，颜色变化带 200ms 过渡。
@Component
export struct StatPill {
  @Prop label: string = '';
  @Prop pillColor: string = DT.bgBrandSoft;
  @Prop textColor: string = DT.brandDeep;
  @Prop pillFontSize: number = DT.fontBody2;

  build() {
    Text(this.label)
      .fontSize(this.pillFontSize)
      .fontColor(this.textColor)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.pillColor)
      .animation({ duration: DT.durFast, curve: Curve.EaseInOut })
      .borderRadius(DT.radiusM);
  }
}
