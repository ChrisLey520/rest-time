export type ProFeature = 'monthly_report' | 'export' | 'billing' | 'weekly_plan';

export interface ProFeatureInfo {
  feature: ProFeature;
  title: string;
  description: string;
}

export const PRO_FEATURES: ProFeatureInfo[] = [
  {
    feature: 'monthly_report',
    title: '月度复盘报告',
    description: '完成率、连续天数、最佳时段、项目投入分布和趋势对比。'
  },
  {
    feature: 'export',
    title: '数据导出',
    description: 'CSV 明细、月报指标和客户账单，可直接交付或存档。'
  },
  {
    feature: 'billing',
    title: '客户账单',
    description: '按项目汇总可结算金额、计费时长、费率和取整规则。'
  },
  {
    feature: 'weekly_plan',
    title: '周计划与结转',
    description: '本周容量、每日建议段数、未完成任务自动结转。'
  }
];

export class ProService {
  // 本地占位：当前始终为 Free，后续接入订阅后替换此处。
  static isPro(): boolean {
    return false;
  }

  static getFeatureInfo(feature: ProFeature): ProFeatureInfo | undefined {
    return PRO_FEATURES.find((item: ProFeatureInfo) => item.feature === feature);
  }
}
