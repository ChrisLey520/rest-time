import { formatSeconds } from '../utils/dateTime';

@Component
export struct TimerDisplay {
  @Prop remainingSeconds: number;
  @Prop timerColor: string = '#1F2A2A';
  // 典藏主题的数字辉光；空字符串表示无辉光。
  @Prop glowColor: string = '';

  build() {
    Text(formatSeconds(this.remainingSeconds))
      .fontSize(72)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.timerColor)
      .letterSpacing(0)
      .textAlign(TextAlign.Center)
      .width('100%')
      .textShadow(this.glowColor
        ? { radius: 18, color: this.glowColor, offsetX: 0, offsetY: 0 }
        : { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 });
  }
}
