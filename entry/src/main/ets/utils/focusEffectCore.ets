import { FocusSession } from '../models/FocusSession';
import { CoinSpend, StreakGuardWallet, timeCoinBalance } from './streakGuardCore';

// 完成动效：专注完成页播放的轻量庆祝动画。
// 纯代码圆环缩放+淡出，无图片资源；用时光币解锁，与保护券/主题共享钱包。
// 典藏级可选能力：haloColor 渲染中心光晕层，waves=2 播放二段波纹。
export interface FocusEffect {
  id: string;
  title: string;
  subtitle: string;
  price: number;
  // 由内向外的圆环颜色，同时决定圆环数量。
  ringColors: string[];
  symbol: string;
  durationMs: number;
  haloColor?: string;
  waves?: number;
}

export const FOCUS_EFFECTS: FocusEffect[] = [
  {
    id: 'ripple',
    title: '涟漪',
    subtitle: '默认的一圈安静涟漪',
    price: 0,
    ringColors: ['#5F9E8A'],
    symbol: '✓',
    durationMs: 900
  },
  {
    id: 'stardust',
    title: '星尘',
    subtitle: '暖金色的两层光晕，适合收下一段深工作',
    price: 250,
    ringColors: ['#B08954', '#E8D5B0'],
    symbol: '✦',
    durationMs: 1100
  },
  {
    id: 'aurora',
    title: '极光',
    subtitle: '青绿到湖蓝的三层光环，给长专注一个仪式感',
    price: 350,
    ringColors: ['#5F9E8A', '#5E9CA8', '#4D7EA8'],
    symbol: '❋',
    durationMs: 1300
  },
  {
    id: 'bloom',
    title: '花信',
    subtitle: '雾紫双环里绽开一朵，温柔地收下这一段',
    price: 300,
    ringColors: ['#8A7FB4', '#D8CFE8'],
    symbol: '❀',
    durationMs: 1200
  },
  {
    id: 'tideline',
    title: '潮线',
    subtitle: '三层深浅海蓝，退潮后留下的完成印记',
    price: 400,
    ringColors: ['#4D7EA8', '#5E9CA8', '#A8CBD6'],
    symbol: '≈',
    durationMs: 1400
  },
  {
    id: 'embers',
    title: '燃点',
    subtitle: '赤陶到暖金的四层烬火，献给最难的那段专注',
    price: 550,
    ringColors: ['#C96F5D', '#B08954', '#E8D5B0', '#F0E4D8'],
    symbol: '✹',
    durationMs: 1600
  },
  {
    id: 'leaf_fall',
    title: '落叶',
    subtitle: '双环木棕，一片叶子落定的轻响',
    price: 280,
    ringColors: ['#A8815E', '#D9C6A8'],
    symbol: '❧',
    durationMs: 1100
  },
  {
    id: 'moonrise',
    title: '月升',
    subtitle: '三层灰蓝托起一轮月，给夜里安静的收束',
    price: 450,
    ringColors: ['#37444A', '#5E7A8A', '#C8D8E8'],
    symbol: '☾',
    durationMs: 1400
  },
  {
    id: 'first_snow',
    title: '初雪',
    subtitle: '四层清浅银灰，落雪无声的完成',
    price: 600,
    ringColors: ['#9AA6A3', '#B8C4C1', '#D6DEDC', '#EEF3F2'],
    symbol: '❄',
    durationMs: 1500
  },
  {
    id: 'zenith',
    title: '天心',
    subtitle: '五层全色环，日晷指向正午——顶级收藏',
    price: 800,
    ringColors: ['#C96F5D', '#B08954', '#7FA05F', '#5E9CA8', '#8A7FB4'],
    symbol: '✺',
    durationMs: 1800
  },
  {
    id: 'gilt_thread',
    title: '鎏金',
    subtitle: '暗金三环带光晕，二段波纹如金箔沉落——典藏',
    price: 1000,
    ringColors: ['#8A6D3B', '#C9A961', '#EFD9A7'],
    symbol: '❖',
    durationMs: 1800,
    haloColor: '#C9A96126',
    waves: 2
  },
  {
    id: 'polar_night',
    title: '极夜',
    subtitle: '墨蓝四环托一点极星，光晕如夜空呼吸——典藏',
    price: 1200,
    ringColors: ['#1E2A3A', '#2E4258', '#4A6A88', '#9FC2DD'],
    symbol: '✧',
    durationMs: 2000,
    haloColor: '#9FC2DD22',
    waves: 2
  },
  {
    id: 'glaze',
    title: '窑变',
    subtitle: '五层釉色从赤铜到天青，每一次完成都开一窑——镇馆',
    price: 1500,
    ringColors: ['#8A4A3A', '#B0764A', '#C9A961', '#7FA0A8', '#5E8CA8'],
    symbol: '✜',
    durationMs: 2200,
    haloColor: '#C9A96130',
    waves: 2
  }
];

export function findFocusEffect(effectId: string): FocusEffect {
  const effect = FOCUS_EFFECTS.find((item: FocusEffect) => item.id === effectId);
  return effect ? effect : FOCUS_EFFECTS[0];
}

export function isEffectUnlocked(effectId: string, wallet: StreakGuardWallet): boolean {
  const effect = findFocusEffect(effectId);
  if (effect.price <= 0) {
    return true;
  }

  return wallet.spends.some((spend: CoinSpend) => spend.kind === `effect_${effect.id}`);
}

export interface UnlockEffectResult {
  ok: boolean;
  wallet: StreakGuardWallet;
  message: string;
}

export function unlockFocusEffect(
  effectId: string,
  sessions: FocusSession[],
  wallet: StreakGuardWallet,
  now: number
): UnlockEffectResult {
  const effect = findFocusEffect(effectId);
  if (effect.price <= 0 || isEffectUnlocked(effectId, wallet)) {
    return {
      ok: false,
      wallet,
      message: '这个动效已经可用'
    };
  }

  const balance = timeCoinBalance(sessions, wallet);
  if (balance < effect.price) {
    return {
      ok: false,
      wallet,
      message: `时光币不足，还差 ${effect.price - balance} 枚`
    };
  }

  const nextSpends = wallet.spends.slice();
  nextSpends.unshift({
    at: now,
    kind: `effect_${effect.id}`,
    amount: effect.price
  });

  return {
    ok: true,
    wallet: {
      heldGuards: wallet.heldGuards,
      coveredDayStarts: wallet.coveredDayStarts.slice(),
      spends: nextSpends
    },
    message: `已解锁「${effect.title}」`
  };
}
