import { DT } from '../utils/designTokens';

// 统一进度条：Stack + 双 Row，填充宽度变化带 280ms 过渡。
@Component
export struct AnimatedProgressBar {
  @Prop percent: number = 0; // 0-100
  @Prop barColor: string = DT.brand;
  @Prop trackColor: string = DT.track;
  @Prop barHeight: number = 7;

  private clampedPercent(): number {
    return Math.max(0, Math.min(100, this.percent));
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(this.barHeight)
        .backgroundColor(this.trackColor)
        .borderRadius(this.barHeight / 2);
      Row()
        .width(`${this.clampedPercent()}%`)
        .backgroundColor(this.barColor)
        .animation({ duration: DT.durBase, curve: Curve.EaseOut })
        .height(this.barHeight)
        .borderRadius(this.barHeight / 2);
    }
    .width('100%');
  }
}
