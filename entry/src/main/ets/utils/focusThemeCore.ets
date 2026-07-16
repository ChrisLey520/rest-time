import { FocusSession } from '../models/FocusSession';
import { CoinSpend, StreakGuardWallet, timeCoinBalance } from './streakGuardCore';

// 专注氛围主题：用时光币解锁的配色，影响专注页背景和计时数字。
// 首个 300 币、递增 100；默认主题永远免费。典藏级可选 timerGlowColor 给数字加辉光。
// symbol 是设置页色块中央的主题图标，取意象字符而非纯色块。
export interface FocusTheme {
  id: string;
  title: string;
  subtitle: string;
  price: number;
  symbol: string;
  backgroundColor: string;
  cardColor: string;
  timerColor: string;
  accentColor: string;
  timerGlowColor?: string;
}

export const FOCUS_THEMES: FocusTheme[] = [
  {
    id: 'default',
    title: '晨雾',
    subtitle: '默认的安静浅色',
    price: 0,
    symbol: '☁',
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
    symbol: '☾',
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
    symbol: '☘',
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
    symbol: '≈',
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
    symbol: '❦',
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
    symbol: '❈',
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
    symbol: '◐',
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
    symbol: '♨',
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
    symbol: '☂',
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
    symbol: '☀',
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
    symbol: '✾',
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
    symbol: '☵',
    backgroundColor: '#101820',
    cardColor: '#182230',
    timerColor: '#C8D8E8',
    accentColor: '#4D7EA8'
  },
  {
    id: 'obsidian_gold',
    title: '鎏金墨',
    subtitle: '黑曜石上描一线暗金，数字带一层微光——典藏',
    price: 1200,
    symbol: '✦',
    backgroundColor: '#121110',
    cardColor: '#1C1A17',
    timerColor: '#E8D9B0',
    accentColor: '#C9A961',
    timerGlowColor: '#C9A96140'
  },
  {
    id: 'aurora_night',
    title: '夜极光',
    subtitle: '极圈夜空的青绿光帘，数字如冰下透光——典藏',
    price: 1500,
    symbol: '✵',
    backgroundColor: '#0D1A1E',
    cardColor: '#14262B',
    timerColor: '#B8F0DC',
    accentColor: '#4FD6A3',
    timerGlowColor: '#4FD6A33A'
  },
  {
    id: 'crimson_lacquer',
    title: '朱漆',
    subtitle: '大漆退光后的深绯，落金般的计时数字——镇馆',
    price: 2000,
    symbol: '❁',
    backgroundColor: '#1C0F0E',
    cardColor: '#2A1614',
    timerColor: '#F2D8A8',
    accentColor: '#C4453C',
    timerGlowColor: '#C4453C33'
  }
];

export function findFocusTheme(themeId: string): FocusTheme {
  const theme = FOCUS_THEMES.find((item: FocusTheme) => item.id === themeId);
  return theme ? theme : FOCUS_THEMES[0];
}

export function isThemeUnlocked(themeId: string, wallet: StreakGuardWallet): boolean {
  const theme = findFocusTheme(themeId);
  if (theme.price <= 0) {
    return true;
  }

  return wallet.spends.some((spend: CoinSpend) => spend.kind === `theme_${theme.id}`);
}

export interface UnlockThemeResult {
  ok: boolean;
  wallet: StreakGuardWallet;
  message: string;
}

export function unlockFocusTheme(
  themeId: string,
  sessions: FocusSession[],
  wallet: StreakGuardWallet,
  now: number
): UnlockThemeResult {
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
