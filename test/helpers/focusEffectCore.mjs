import { timeCoinBalance } from './streakGuardCore.mjs';

export const FOCUS_EFFECTS = [
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

export function findFocusEffect(effectId) {
  const effect = FOCUS_EFFECTS.find((item) => item.id === effectId);
  return effect || FOCUS_EFFECTS[0];
}

export function isEffectUnlocked(effectId, wallet) {
  const effect = findFocusEffect(effectId);
  if (effect.price <= 0) {
    return true;
  }

  return wallet.spends.some((spend) => spend.kind === `effect_${effect.id}`);
}

export function unlockFocusEffect(effectId, sessions, wallet, now) {
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
