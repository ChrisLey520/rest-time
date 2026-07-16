import { timeCoinBalance } from './streakGuardCore.mjs';

export const FOCUS_THEMES = [
  {
    id: 'default',
    title: '晨雾',
    subtitle: '默认的安静浅色',
    price: 0,
    backgroundColor: '#F6F8F7',
    cardColor: '#FFFFFF',
    timerColor: '#1F2A2A',
    accentColor: '#5F9E8A'
  },
  {
    id: 'dusk',
    title: '暮色',
    subtitle: '低亮度的暖夜色，适合晚间专注',
    price: 300,
    backgroundColor: '#23282E',
    cardColor: '#2C333B',
    timerColor: '#E8E2D5',
    accentColor: '#B08954'
  },
  {
    id: 'forest',
    title: '林间',
    subtitle: '深绿基调，把桌面变成一片安静的林地',
    price: 400,
    backgroundColor: '#1F2E28',
    cardColor: '#28382F',
    timerColor: '#E4EFE7',
    accentColor: '#7FA05F'
  },
  {
    id: 'tide',
    title: '潮汐',
    subtitle: '深海蓝，配合长时间深度专注',
    price: 500,
    backgroundColor: '#1E2833',
    cardColor: '#273443',
    timerColor: '#DCE8F2',
    accentColor: '#5E9CA8'
  }
];

export function findFocusTheme(themeId) {
  const theme = FOCUS_THEMES.find((item) => item.id === themeId);
  return theme || FOCUS_THEMES[0];
}

export function isThemeUnlocked(themeId, wallet) {
  const theme = findFocusTheme(themeId);
  if (theme.price <= 0) {
    return true;
  }

  return wallet.spends.some((spend) => spend.kind === `theme_${theme.id}`);
}

export function unlockFocusTheme(themeId, sessions, wallet, now) {
  const theme = findFocusTheme(themeId);
  if (theme.price <= 0 || isThemeUnlocked(themeId, wallet)) {
    return {
      ok: false,
      wallet,
      message: '这个氛围已经可用'
    };
  }

  const balance = timeCoinBalance(sessions, wallet);
  if (balance < theme.price) {
    return {
      ok: false,
      wallet,
      message: `时光币不足，还差 ${theme.price - balance} 枚`
    };
  }

  const nextSpends = wallet.spends.slice();
  nextSpends.unshift({
    at: now,
    kind: `theme_${theme.id}`,
    amount: theme.price
  });

  return {
    ok: true,
    wallet: {
      heldGuards: wallet.heldGuards,
      coveredDayStarts: wallet.coveredDayStarts.slice(),
      spends: nextSpends
    },
    message: `已解锁「${theme.title}」`
  };
}
