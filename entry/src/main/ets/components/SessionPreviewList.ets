import { FocusSession } from '../models/FocusSession';
import { formatClockTime, formatDuration } from '../utils/dateTime';

@Component
export struct SessionPreviewList {
  @Prop sessions: FocusSession[];

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('最近记录')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2A2A');
      }
      .width('100%');

      if (this.sessions.length === 0) {
        Text('还没有记录。先安放一小段时间。')
          .fontSize(14)
          .fontColor('#7B8785')
          .width('100%')
          .padding({ top: 8, bottom: 8 });
      } else {
        ForEach(this.sessions, (session: FocusSession) => {
          Row() {
            Column({ space: 4 }) {
              Text(session.taskTitle ? session.taskTitle : '自由专注')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1F2A2A');
              Text(`${formatClockTime(session.startedAt)} - ${formatClockTime(session.endedAt)}`)
                .fontSize(12)
                .fontColor('#7B8785');
              if (session.awaySeconds && session.awaySeconds > 0) {
                Text(`离开 ${formatDuration(session.awaySeconds)} 未计入`)
                  .fontSize(11)
                  .fontColor('#C96F5D');
              }
              if (session.returnProofRequiredCount && session.returnProofRequiredCount > 0) {
                Text(`守门整理 ${session.returnProofCompletedCount ? session.returnProofCompletedCount : 0}/${session.returnProofRequiredCount} 次`)
                  .fontSize(11)
                  .fontColor('#4D7EA8');
              }
              if (session.focusIntegrityStatus === 'violated') {
                Text('守门违规：离开白名单')
                  .fontSize(11)
                  .fontColor('#C96F5D');
              }
              if (session.starterPlanRiskLevel && session.starterPlanRiskLevel !== 'low') {
                Text(session.starterPlanRiskLevel === 'high' ? '高风险保底启动' : '易分心保底启动')
                  .fontSize(11)
                  .fontColor(session.starterPlanRiskLevel === 'high' ? '#C96F5D' : '#4D7EA8');
              }
              if (session.handoffNote && session.handoffNote.trim()) {
                Text(`交接：${session.handoffNote}`)
                  .fontSize(11)
                  .fontColor('#4D7EA8')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              if (session.microActionCompletedCount && session.microActionCompletedCount > 0) {
                Text(`小动作 ${session.microActionCompletedCount} 次`)
                  .fontSize(11)
                  .fontColor('#5F9E8A');
              }
              if (session.timeCoinsEarned && session.timeCoinsEarned > 0) {
                Text(`时光币 +${session.timeCoinsEarned}`)
                  .fontSize(11)
                  .fontColor('#4D7EA8');
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);

            Column({ space: 4 }) {
              Text(session.status === 'completed' ? '已完成' : '已结束')
                .fontSize(13)
                .fontColor(session.status === 'completed' ? '#5F9E8A' : '#C96F5D');
              Text(formatDuration(session.actualDurationSeconds))
                .fontSize(12)
                .fontColor('#7B8785');
              if (session.restartFromReason === 'abandoned_retry') {
                Text('低谷重启')
                  .fontSize(11)
                  .fontColor('#4D7EA8');
              }
            }
            .alignItems(HorizontalAlign.End);
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .border({
            width: 1,
            color: '#DDE8EA'
          });
        }, (session: FocusSession) => session.id);
      }
    }
    .width('100%');
  }
}
