import { FocusSession } from '../models/FocusSession';
import { formatClockTime, formatDuration } from '../utils/dateTime';
import { DT } from '../utils/designTokens';

@Component
export struct SessionPreviewList {
  @Prop sessions: FocusSession[];

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('最近记录')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(DT.textPrimary);
      }
      .width('100%');

      if (this.sessions.length === 0) {
        Text('还没有记录。先安放一小段时间。')
          .fontSize(14)
          .fontColor(DT.textSecondary)
          .width('100%')
          .padding({ top: 8, bottom: 8 });
      } else {
        ForEach(this.sessions, (session: FocusSession) => {
          Row() {
            Column({ space: 4 }) {
              Text(session.taskTitle ? session.taskTitle : '自由专注')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(DT.textPrimary);
              Text(`${formatClockTime(session.startedAt)} - ${formatClockTime(session.endedAt)}`)
                .fontSize(12)
                .fontColor(DT.textSecondary);
              if (session.awaySeconds && session.awaySeconds > 0) {
                Text(`离开 ${formatDuration(session.awaySeconds)} 未计入`)
                  .fontSize(11)
                  .fontColor(DT.danger);
              }
              if (session.returnProofRequiredCount && session.returnProofRequiredCount > 0) {
                Text(`守门整理 ${session.returnProofCompletedCount ? session.returnProofCompletedCount : 0}/${session.returnProofRequiredCount} 次`)
                  .fontSize(11)
                  .fontColor(DT.info);
              }
              if (session.focusIntegrityStatus === 'violated') {
                Text('守门违规：离开白名单')
                  .fontSize(11)
                  .fontColor(DT.danger);
              }
              if (session.starterPlanRiskLevel && session.starterPlanRiskLevel !== 'low') {
                Text(session.starterPlanRiskLevel === 'high' ? '高风险保底启动' : '易分心保底启动')
                  .fontSize(11)
                  .fontColor(session.starterPlanRiskLevel === 'high' ? DT.danger : DT.info);
              }
              if (session.handoffNote && session.handoffNote.trim()) {
                Text(`交接：${session.handoffNote}`)
                  .fontSize(11)
                  .fontColor(DT.info)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              if (session.microActionCompletedCount && session.microActionCompletedCount > 0) {
                Text(`小动作 ${session.microActionCompletedCount} 次`)
                  .fontSize(11)
                  .fontColor(DT.brand);
              }
              if (session.timeCoinsEarned && session.timeCoinsEarned > 0) {
                Text(`时光币 +${session.timeCoinsEarned}`)
                  .fontSize(11)
                  .fontColor(DT.info);
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);

            Column({ space: 4 }) {
              Text(session.status === 'completed' ? '已完成' : '已结束')
                .fontSize(13)
                .fontColor(session.status === 'completed' ? DT.brand : DT.danger);
              Text(formatDuration(session.actualDurationSeconds))
                .fontSize(12)
                .fontColor(DT.textSecondary);
              if (session.restartFromReason === 'abandoned_retry') {
                Text('低谷重启')
                  .fontSize(11)
                  .fontColor(DT.info);
              }
            }
            .alignItems(HorizontalAlign.End);
          }
          .width('100%')
          .padding(14)
          .backgroundColor(DT.bgCard)
          .borderRadius(DT.radiusM)
          .shadow(DT.shadowContact);
        }, (session: FocusSession) => session.id);
      }
    }
    .width('100%');
  }
}
