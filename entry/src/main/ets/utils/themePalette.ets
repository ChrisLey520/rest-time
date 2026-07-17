import { FocusTheme } from './focusThemeCore';
import { DT } from './designTokens';

// 主题桥接：把 FocusTheme 的配色转换成新的表面样式（渐变 + 阴影）。
// 浅色主题走标准双层柔影；深色主题阴影不可见，改用「顶部受光」渐变制造层次。
export interface SurfaceStyle {
  cardTop: string;
  cardBottom: string;
  shadowAmbient: ShadowOptions;
  shadowContact: ShadowOptions;
}

// 解析 #RRGGBB（或 #AARRGGBB 的后 6 位）为通道数组；解析失败返回 null。
function parseHexChannels(hex: string): number[] | null {
  const raw = hex.startsWith('#') ? hex.substring(1) : hex;
  const rgb = raw.length === 8 ? raw.substring(2) : raw;
  if (rgb.length !== 6) {
    return null;
  }
  const r = parseInt(rgb.substring(0, 2), 16);
  const g = parseInt(rgb.substring(2, 4), 16);
  const b = parseInt(rgb.substring(4, 6), 16);
  if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) {
    return null;
  }
  return [r, g, b];
}

function channelToHex(value: number): string {
  const clamped = Math.max(0, Math.min(255, Math.round(value)));
  const text = clamped.toString(16);
  return text.length === 1 ? `0${text}` : text;
}

// 把颜色向白色方向提亮 amount（0-1）。
export function lightenHex(hex: string, amount: number): string {
  const channels = parseHexChannels(hex);
  if (!channels) {
    return hex;
  }
  const r = channelToHex(channels[0] + (255 - channels[0]) * amount);
  const g = channelToHex(channels[1] + (255 - channels[1]) * amount);
  const b = channelToHex(channels[2] + (255 - channels[2]) * amount);
  return `#${r}${g}${b}`;
}

export function isDarkTheme(theme: FocusTheme): boolean {
  const channels = parseHexChannels(theme.backgroundColor);
  if (!channels) {
    return false;
  }
  const luminance = (0.299 * channels[0] + 0.587 * channels[1] + 0.114 * channels[2]) / 255;
  return luminance < 0.5;
}

// 默认浅色表面（未激活主题时的白卡）。
export function defaultSurface(): SurfaceStyle {
  return {
    cardTop: DT.bgCard,
    cardBottom: DT.bgCardTint,
    shadowAmbient: DT.shadowAmbient,
    shadowContact: DT.shadowContact
  };
}

export function surfaceFor(theme: FocusTheme, active: boolean): SurfaceStyle {
  if (!active) {
    return defaultSurface();
  }
  if (isDarkTheme(theme)) {
    // 深色底上投影不可见且发灰：去掉阴影，用「顶部微亮」渐变制造受光层次。
    return {
      cardTop: lightenHex(theme.cardColor, 0.05),
      cardBottom: theme.cardColor,
      shadowAmbient: DT.shadowNone,
      shadowContact: DT.shadowNone
    };
  }
  return {
    cardTop: theme.cardColor,
    cardBottom: lightenHex(theme.cardColor, 0.35),
    shadowAmbient: DT.shadowAmbient,
    shadowContact: DT.shadowContact
  };
}
