import { FocusEffect } from '../utils/focusEffectCore';

/**
 * 完成动效：由内向外的多层圆环缩放淡出 + 中心符号弹入。
 * 纯声明式动画，无图片资源；effect.ringColors 决定层数和配色。
 */
@Component
export struct CompletionEffect {
  @Prop effect: FocusEffect;
  // 用外部递增的播放序号触发重播（同一次完成只播一次）。
  @Prop playToken: number = 0;
  @State ringScale: number = 0.4;
  @State ringOpacity: number = 0;
  @State symbolScale: number = 0.2;
  @State symbolOpacity: number = 0;

  aboutToAppear(): void {
    this.play();
  }

  private play(): void {
    this.ringScale = 0.4;
    this.ringOpacity = 0.9;
    this.symbolScale = 0.2;
    this.symbolOpacity = 0;

    this.getUIContext().animateTo({
      duration: this.effect.durationMs,
      curve: Curve.EaseOut
    }, () => {
      this.ringScale = 1.6;
      this.ringOpacity = 0;
    });

    this.getUIContext().animateTo({
      duration: Math.floor(this.effect.durationMs / 2),
      curve: Curve.Friction
    }, () => {
      this.symbolScale = 1;
      this.symbolOpacity = 1;
    });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      ForEach(this.effect.ringColors, (color: string, index: number) => {
        Column()
          .width(64 + index * 26)
          .height(64 + index * 26)
          .borderRadius((64 + index * 26) / 2)
          .border({
            width: 3,
            color: color
          })
          .scale({ x: this.ringScale, y: this.ringScale })
          .opacity(this.ringOpacity);
      }, (color: string, index: number) => `${this.playToken}_${index}_${color}`);

      Text(this.effect.symbol)
        .fontSize(34)
        .fontColor(this.effect.ringColors[0])
        .scale({ x: this.symbolScale, y: this.symbolScale })
        .opacity(this.symbolOpacity);
    }
    .width('100%')
    .height(130);
  }
}
