import { DT } from '../utils/designTokens';

export interface StatItem {
  value: string;
  label: string;
  valueColor?: string;
}

// 统一多列统计行：数值 + 小标签，等宽分布。
@Component
export struct StatTripleRow {
  @Prop items: StatItem[] = [];
  @Prop valueColor: string = DT.textPrimary;
  @Prop labelColor: string = DT.textSecondary;

  build() {
    Row({ space: DT.spaceS }) {
      ForEach(this.items, (item: StatItem) => {
        Column({ space: 3 }) {
          Text(item.value)
            .fontSize(DT.fontTitle)
            .fontWeight(FontWeight.Medium)
            .fontColor(item.valueColor ? item.valueColor : this.valueColor)
            .animation({ duration: DT.durFast, curve: Curve.EaseInOut });
          Text(item.label)
            .fontSize(DT.fontCaption)
            .fontColor(this.labelColor);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center);
      }, (item: StatItem, index: number) => `${index}_${item.label}`);
    }
    .width('100%');
  }
}
