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
  },
  {
    id: 'paper',
    title: '宣纸',
    subtitle: '暖白纸感，白天书房里的安静底色',
    price: 350,
    backgroundColor: '#F5F0E6',
    cardColor: '#FCF9F2',
    timerColor: '#3A342A',
    accentColor: '#A8815E'
  },
  {
    id: 'bamboo',
    title: '竹影',
    subtitle: '清浅豆绿，清晨窗边的一盏竹',
    price: 450,
    backgroundColor: '#EBF1E8',
    cardColor: '#F7FAF5',
    timerColor: '#2C3A2E',
    accentColor: '#7FA05F'
  },
  {
    id: 'ink',
    title: '墨夜',
    subtitle: '近乎全黑的极简，深夜最后一段专注',
    price: 600,
    backgroundColor: '#15181B',
    cardColor: '#1E2226',
    timerColor: '#D9DDDB',
    accentColor: '#8A7FB4'
  },
  {
    id: 'ember',
    title: '余烬',
    subtitle: '炭黑里一点暖橘，收藏级的沉静',
    price: 800,
    backgroundColor: '#241F1C',
    cardColor: '#2E2824',
    timerColor: '#F0E4D8',
    accentColor: '#C96F5D'
  },
  {
    id: 'mist_rain',
    title: '烟雨',
    subtitle: '灰青水汽，落雨天窗边的专注',
    price: 380,
    backgroundColor: '#E8EDEE',
    cardColor: '#F4F7F8',
    timerColor: '#37444A',
    accentColor: '#5E9CA8'
  },
  {
    id: 'dawn',
    title: '破晓',
    subtitle: '天亮前的青灰与一线暖光，给早起第一段',
    price: 520,
    backgroundColor: '#2A3038',
    cardColor: '#343B45',
    timerColor: '#F2E9DA',
    accentColor: '#D9A662'
  },
  {
    id: 'wheat',
    title: '麦浪',
    subtitle: '干燥的暖黄，午后田野的踏实感',
    price: 560,
    backgroundColor: '#F3EBDA',
    cardColor: '#FAF5EA',
    timerColor: '#4A3F2E',
    accentColor: '#B08954'
  },
  {
    id: 'deep_sea',
    title: '深壑',
    subtitle: '海面千米之下，只剩你和这一段时间',
    price: 1000,
    backgroundColor: '#101820',
    cardColor: '#182230',
    timerColor: '#C8D8E8',
    accentColor: '#4D7EA8'
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
