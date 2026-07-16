import {
  buyStreakGuard,
  guardedStreakDays,
  STREAK_GUARD_MAX_HELD,
  STREAK_GUARD_PRICE,
  StreakDayState,
  StreakGuardWallet,
  timeCoinBalance
} from '../utils/streakGuardCore';
import { startOfDayMs } from '../utils/statsCore';
import { FocusSession } from '../models/FocusSession';
import { SessionService } from './SessionService';
import { StorageService } from './StorageService';

export { STREAK_GUARD_MAX_HELD, STREAK_GUARD_PRICE, StreakGuardWallet };

export interface StreakGuardSnapshot {
  streakDays: number;
  heldGuards: number;
  coinBalance: number;
}

export interface BuyGuardOutcome {
  ok: boolean;
  message: string;
  snapshot: StreakGuardSnapshot;
}

function hasCompletedFocus(sessions: FocusSession[], startAt: number, endAt: number): boolean {
  return sessions.some((session: FocusSession) => {
    return session.status === 'completed'
      && session.countsAsFocus !== false
      && session.endedAt >= startAt
      && session.endedAt < endAt;
  });
}

function createDayStates(sessions: FocusSession[], wallet: StreakGuardWallet, now: number): StreakDayState[] {
  const dayStates: StreakDayState[] = [];
  const coveredSet: Set<number> = new Set(wallet.coveredDayStarts);
  for (let offset = 0; offset > -365; offset -= 1) {
    const startAt = startOfDayMs(now, offset);
    const endAt = offset === 0 ? now + 1 : startOfDayMs(now, offset + 1);
    if (hasCompletedFocus(sessions, startAt, endAt)) {
      dayStates.push('focus');
    } else if (coveredSet.has(startAt)) {
      dayStates.push('covered');
    } else {
      dayStates.push('blank');
    }
  }

  return dayStates;
}

export class StreakGuardService {
  /**
   * 计算带保护券的节奏天数。如果本次计算消耗了保护券，
   * 立即持久化扣减并把被覆盖的日期记入 coveredDayStarts，保证不重复扣券。
   */
  static async getSnapshot(): Promise<StreakGuardSnapshot> {
    const sessions = await SessionService.listAll();
    const wallet = await StorageService.getStreakGuardWallet();
    const now = Date.now();
    const dayStates = createDayStates(sessions, wallet, now);
    const result = guardedStreakDays(dayStates, wallet.heldGuards);

    if (result.guardsConsumed > 0) {
      const nextCovered = wallet.coveredDayStarts.slice();
      result.coveredIndexes.forEach((index: number) => {
        nextCovered.push(startOfDayMs(now, -index));
      });
      const nextWallet: StreakGuardWallet = {
        heldGuards: Math.max(0, wallet.heldGuards - result.guardsConsumed),
        coveredDayStarts: nextCovered,
        spends: wallet.spends
      };
      await StorageService.saveStreakGuardWallet(nextWallet);
      return {
        streakDays: result.streakDays,
        heldGuards: nextWallet.heldGuards,
        coinBalance: timeCoinBalance(sessions, nextWallet)
      };
    }

    return {
      streakDays: result.streakDays,
      heldGuards: wallet.heldGuards,
      coinBalance: timeCoinBalance(sessions, wallet)
    };
  }

  static async buyGuard(): Promise<BuyGuardOutcome> {
    const sessions = await SessionService.listAll();
    const wallet = await StorageService.getStreakGuardWallet();
    const result = buyStreakGuard(sessions, wallet, Date.now());
    if (result.ok) {
      await StorageService.saveStreakGuardWallet(result.wallet);
    }

    const snapshot = await StreakGuardService.getSnapshot();
    return {
      ok: result.ok,
      message: result.message,
      snapshot
    };
  }
}
