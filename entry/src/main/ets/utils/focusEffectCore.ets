import { FocusSession } from '../models/FocusSession';
import { CoinSpend, StreakGuardWallet, timeCoinBalance } from './streakGuardCore';

// 完成动效：专注完成页播放的轻量庆祝动画。
// 纯代码圆环缩放+淡出，无图片资源；用时光币解锁，与保护券/主题共享钱包。
export interface FocusEffect {
  id: string;
  title: string;
  subtitle: string;
  price: number;
  // 由内向外的圆环颜色，同时决定圆环数量。
  ringColors: string[];
  symbol: string;
  durationMs: number;
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
