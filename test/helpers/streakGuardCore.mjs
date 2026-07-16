export const STREAK_GUARD_PRICE = 120;
export const STREAK_GUARD_MAX_HELD = 2;

export function createEmptyWallet() {
  return {
    heldGuards: 0,
    coveredDayStarts: [],
    spends: []
  };
}

export function normalizeWallet(wallet) {
  if (!wallet) {
    return createEmptyWallet();
  }

  return {
    heldGuards: Math.max(0, Math.floor(wallet.heldGuards || 0)),
    coveredDayStarts: wallet.coveredDayStarts || [],
    spends: wallet.spends || []
  };
}

export function totalEarnedTimeCoins(sessions) {
  let total = 0;
  sessions.forEach((session) => {
    total += session.timeCoinsEarned || 0;
  });

  return Math.max(0, Math.floor(total));
}

export function totalSpentTimeCoins(wallet) {
  let total = 0;
  wallet.spends.forEach((spend) => {
    total += spend.amount > 0 ? spend.amount : 0;
  });

  return Math.max(0, Math.floor(total));
}

export function timeCoinBalance(sessions, wallet) {
  return Math.max(0, totalEarnedTimeCoins(sessions) - totalSpentTimeCoins(wallet));
}

export function buyStreakGuard(sessions, wallet, now) {
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
      spends: nextSpends
    },
    message: '已兑换 1 张节奏保护券'
  };
}

export function guardedStreakDays(dayStates, heldGuards) {
  let streakDays = 0;
  let guardsConsumed = 0;
  const coveredIndexes = [];
  let lastRestIndex = -1;
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
