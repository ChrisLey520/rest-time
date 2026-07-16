import { FocusSession } from '../models/FocusSession';

// 节奏保护券：用时光币兑换的额外休息日。
// 弹性节奏每 7 天有 1 个免费休息日；免费日用完后缺席，自动消耗一张保护券，节奏不断。
export const STREAK_GUARD_PRICE = 120;
export const STREAK_GUARD_MAX_HELD = 2;

export interface CoinSpend {
  at: number;
  kind: string;
  amount: number;
}

export interface StreakGuardWallet {
  heldGuards: number;
  coveredDayStarts: number[];
  spends: CoinSpend[];
  // 调试/运营补发的时光币，计入余额；正式发放仍走 session 的 timeCoinsEarned。
  bonusCoins: number;
}

export function createEmptyWallet(): StreakGuardWallet {
  return {
    heldGuards: 0,
    coveredDayStarts: [],
    spends: [],
    bonusCoins: 0
  };
}

export function normalizeWallet(wallet?: StreakGuardWallet): StreakGuardWallet {
  if (!wallet) {
    return createEmptyWallet();
  }

  return {
    heldGuards: Math.max(0, Math.floor(wallet.heldGuards ? wallet.heldGuards : 0)),
    coveredDayStarts: wallet.coveredDayStarts ? wallet.coveredDayStarts : [],
    spends: wallet.spends ? wallet.spends : [],
    bonusCoins: Math.max(0, Math.floor(wallet.bonusCoins ? wallet.bonusCoins : 0))
  };
}

export function totalEarnedTimeCoins(sessions: FocusSession[]): number {
  let total = 0;
  sessions.forEach((session: FocusSession) => {
    total += session.timeCoinsEarned ? session.timeCoinsEarned : 0;
  });

  return Math.max(0, Math.floor(total));
}

export function totalSpentTimeCoins(wallet: StreakGuardWallet): number {
  let total = 0;
  wallet.spends.forEach((spend: CoinSpend) => {
    total += spend.amount > 0 ? spend.amount : 0;
  });

  return Math.max(0, Math.floor(total));
}

export function timeCoinBalance(sessions: FocusSession[], wallet: StreakGuardWallet): number {
  return Math.max(0, totalEarnedTimeCoins(sessions) + wallet.bonusCoins - totalSpentTimeCoins(wallet));
}

export interface BuyStreakGuardResult {
  ok: boolean;
  wallet: StreakGuardWallet;
  message: string;
}

export function buyStreakGuard(
  sessions: FocusSession[],
  wallet: StreakGuardWallet,
  now: number
): BuyStreakGuardResult {
  if (wallet.heldGuards >= STREAK_GUARD_MAX_HELD) {
    return {
      ok: false,
      wallet,
      message: `最多持有 ${STREAK_GUARD_MAX_HELD} 张保护券`
    };
  }

  const balance = timeCoinBalance(sessions, wallet);
  if (balance < STREAK_GUARD_PRICE) {
    return {
      ok: false,
      wallet,
      message: `时光币不足，还差 ${STREAK_GUARD_PRICE - balance} 枚`
    };
  }

  const nextSpends = wallet.spends.slice();
  nextSpends.unshift({
    at: now,
    kind: 'streak_guard',
    amount: STREAK_GUARD_PRICE
  });

  return {
    ok: true,
    wallet: {
      heldGuards: wallet.heldGuards + 1,
      coveredDayStarts: wallet.coveredDayStarts.slice(),
      spends: nextSpends,
      bonusCoins: wallet.bonusCoins
    },
    message: '已兑换 1 张节奏保护券'
  };
}

// 一天的三种状态：有专注 / 空白 / 已被保护券覆盖（历史消耗过，不再重复扣券）。
export type StreakDayState = 'focus' | 'blank' | 'covered';

export interface GuardedStreakResult {
  streakDays: number;
  guardsConsumed: number;
  coveredIndexes: number[];
}

/**
 * 弹性节奏 + 保护券的连续天数。
 * dayStates[0] 是今天、[1] 是昨天……
 * 规则：今天空白不算断；covered 日直接视为已保护；blank 日先用每 7 天 1 次的
 * 免费休息日，用完再消耗保护券（记录下标供调用方持久化），都没有则节奏中断。
 */
export function guardedStreakDays(dayStates: StreakDayState[], heldGuards: number): GuardedStreakResult {
  let streakDays = 0;
  let guardsConsumed = 0;
  const coveredIndexes: number[] = [];
  let lastRestIndex = -1; // 尚未使用免费休息日
  let remainingGuards = Math.max(0, Math.floor(heldGuards));

  if (dayStates.length > 0 && dayStates[0] === 'focus') {
    streakDays += 1;
  }

  for (let index = 1; index < dayStates.length; index += 1) {
    if (dayStates[index] === 'focus') {
      streakDays += 1;
      continue;
    }

    if (dayStates[index] === 'covered') {
      continue;
    }

    // 空白日：先免费休息日，再保护券。
    if (lastRestIndex < 0 || index - lastRestIndex >= 7) {
      lastRestIndex = index;
      continue;
    }

    if (remainingGuards > 0) {
      remainingGuards -= 1;
      guardsConsumed += 1;
      coveredIndexes.push(index);
      continue;
    }

    break;
  }

  return {
    streakDays,
    guardsConsumed,
    coveredIndexes
  };
}
