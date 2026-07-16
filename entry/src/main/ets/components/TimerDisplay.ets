import { formatSeconds } from '../utils/dateTime';

@Component
export struct TimerDisplay {
  @Prop remainingSeconds: number;
  @Prop timerColor: string = '#1F2A2A';

  build() {
    Text(formatSeconds(this.remainingSeconds))
      .fontSize(72)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.timerColor)
      .letterSpacing(0)
      .textAlign(TextAlign.Center)
      .width('100%');
  }
}
