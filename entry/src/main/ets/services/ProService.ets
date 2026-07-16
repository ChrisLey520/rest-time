import { isProActive, proBadgeText, ProState, proStatusText } from '../utils/proCore';
import { StorageService } from './StorageService';

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

export interface ProSnapshot {
  active: boolean;
  statusText: string;
  badgeText: string;
}

export class ProService {
  // 体验期策略：订阅未上线时 proState 恒为 none，Pro 能力全部免费开放。
  // IAP 接入点：支付成功/收据校验后调用 activate() 写入订阅状态；
  // 各能力入口的锁定判断统一走 getSnapshot().active。
  static async getSnapshot(): Promise<ProSnapshot> {
    const state = await StorageService.getProState();
    const now = Date.now();
    return {
      active: isProActive(state, now),
      statusText: proStatusText(state, now),
      badgeText: proBadgeText(state, now)
    };
  }

  /** IAP 支付回调/恢复购买后写入订阅状态。source 传 'iap'；运营赠送传 'promo'。 */
  static async activate(state: ProState): Promise<void> {
    await StorageService.saveProState(state);
  }

  static getFeatureInfo(feature: ProFeature): ProFeatureInfo | undefined {
    return PRO_FEATURES.find((item: ProFeatureInfo) => item.feature === feature);
  }
}
