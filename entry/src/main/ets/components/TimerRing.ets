import { DT } from '../utils/designTokens';
import { formatSeconds } from '../utils/dateTime';

// 计时主体：圆环进度 + 数字。环随剩余时间消退；
// 运行中整体缓慢呼吸（scale 1→1.02 + 环透明度 0.85→1）。
// 进度用本地 @State + 550ms 线性动画覆盖 500ms 轮询间隔，消除逐秒台阶。
@Component
export struct TimerRing {
  @Prop @Watch('onRemainingChange') remainingSeconds: number = 0;
  @Prop totalSeconds: number = 0;
  @Prop @Watch('onRunningChange') running: boolean = false;
  @Prop ringColor: string = DT.brand;
  @Prop trackColor: string = DT.track;
  @Prop digitColor: string = DT.textPrimary;
  @Prop glowColor: string = '';
  @Prop captionText: string = '';
  @Prop captionColor: string = DT.textSecondary;
  @Prop ringSize: number = 240;

  @State private ringProgress: number = 100;
  @State private breathScale: number = 1;
  @State private ringOpacity: number = 1;

  aboutToAppear(): void {
    this.ringProgress = this.progressOf(this.remainingSeconds);
    if (this.running) {
      this.startBreath();
    }
  }

  private progressOf(remaining: number): number {
    if (this.totalSeconds <= 0) {
      return 100;
    }
    return Math.max(0, Math.min(100, (remaining / this.totalSeconds) * 100));
  }

  onRemainingChange(): void {
    const next = this.progressOf(this.remainingSeconds);
    this.getUIContext().animateTo({ duration: 550, curve: Curve.Linear }, () => {
      this.ringProgress = next;
    });
  }

  onRunningChange(): void {
    if (this.running) {
      this.startBreath();
    } else {
      this.stopBreath();
    }
  }

  private startBreath(): void {
    this.getUIContext().animateTo({
      duration: DT.durBreath,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.breathScale = 1.02;
      this.ringOpacity = 0.85;
    });
  }

  private stopBreath(): void {
    this.getUIContext().animateTo({ duration: DT.durFast, curve: Curve.EaseOut }, () => {
      this.breathScale = 1;
      this.ringOpacity = 1;
    });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({ value: this.ringProgress, total: 100, type: ProgressType.Ring })
        .width(this.ringSize)
        .height(this.ringSize)
        .color(this.ringColor)
        .backgroundColor(this.trackColor)
        .style({ strokeWidth: 10, enableSmoothEffect: true })
        .opacity(this.ringOpacity)
        .animation({ duration: DT.durSlow, curve: Curve.EaseInOut });

      Column({ space: 6 }) {
        Text(formatSeconds(this.remainingSeconds))
          .fontSize(54)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.digitColor)
          .animation({ duration: DT.durSlow, curve: Curve.EaseInOut })
          .textAlign(TextAlign.Center)
          .textShadow(this.glowColor
            ? { radius: 18, color: this.glowColor, offsetX: 0, offsetY: 0 }
            : { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 });

        if (this.captionText) {
          Text(this.captionText)
            .fontSize(DT.fontBody2)
            .fontColor(this.captionColor)
            .animation({ duration: DT.durSlow, curve: Curve.EaseInOut })
            .textAlign(TextAlign.Center);
        }
      }
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .scale({ x: this.breathScale, y: this.breathScale });
  }
}
