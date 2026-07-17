// 全局设计 token：颜色、圆角、字号、间距、阴影、动效常量。
// UI 层统一从这里取值，避免硬编码散落；focusThemeCore/focusEffectCore
// 里的主题配色属于「内容数据」，不在此列。
export class DT {
  // —— 颜色 ——
  static readonly brand: string = '#5F9E8A';
  static readonly brandDeep: string = '#4E8A77';
  static readonly brandLight: string = '#68A996';
  static readonly info: string = '#4D7EA8';
  static readonly infoDeep: string = '#426E94';
  static readonly infoLight: string = '#5B8BB4';
  static readonly danger: string = '#C96F5D';
  static readonly dangerDeep: string = '#B65F4E';
  static readonly dangerLight: string = '#D07E6D';
  static readonly textPrimary: string = '#1F2A2A';
  static readonly textSecondary: string = '#7B8785';
  static readonly textPlaceholder: string = '#9AA6A3';
  static readonly bgPage: string = '#F6F8F7';
  static readonly bgCard: string = '#FFFFFF';
  static readonly bgCardTint: string = '#FAFCFB';
  static readonly bgBrandSoft: string = '#EAF3F0';
  static readonly bgInfoSoft: string = '#EAF2F8';
  static readonly bgDangerSoft: string = '#FFF0EC';
  static readonly bgNeutralSoft: string = '#F1F3F2';
  static readonly bgInput: string = '#F6F8F7';
  static readonly track: string = '#EEF3F2';
  static readonly divider: string = '#EEF3F2';
  static readonly disabledBg: string = '#E4EAE9';
  static readonly transparent: string = '#00000000';

  // —— 圆角（4 档）——
  static readonly radiusS: number = 10;
  static readonly radiusM: number = 14;
  static readonly radiusL: number = 18;
  static readonly radiusXL: number = 22;

  // —— 字号（7 档 + 计时数字）——
  static readonly fontCaption: number = 11;
  static readonly fontFootnote: number = 12;
  static readonly fontBody2: number = 13;
  static readonly fontBody: number = 15;
  static readonly fontTitle: number = 17;
  static readonly fontHeadline: number = 20;
  static readonly fontDisplay: number = 28;

  // —— 间距 ——
  static readonly spaceXS: number = 6;
  static readonly spaceS: number = 10;
  static readonly spaceM: number = 14;
  static readonly spaceL: number = 20;
  static readonly spaceXL: number = 28;

  // —— 按钮高度（3 档）——
  static readonly buttonS: number = 34;
  static readonly buttonM: number = 44;
  static readonly buttonL: number = 52;

  // —— 阴影：双层柔影用外层 ambient + 内层 contact 叠加逼近 ——
  static readonly shadowAmbient: ShadowOptions = {
    radius: 24,
    color: '#0D31443E',
    offsetX: 0,
    offsetY: 8
  };
  static readonly shadowContact: ShadowOptions = {
    radius: 6,
    color: '#0A1F2A2A',
    offsetX: 0,
    offsetY: 2
  };
  static readonly shadowButton: ShadowOptions = {
    radius: 10,
    color: '#2E5F9E8A',
    offsetX: 0,
    offsetY: 4
  };
  static readonly shadowNone: ShadowOptions = {
    radius: 0,
    color: '#00000000',
    offsetX: 0,
    offsetY: 0
  };

  // —— 动效 ——
  static readonly durFast: number = 200;
  static readonly durBase: number = 280;
  static readonly durSlow: number = 400;
  static readonly durBreath: number = 2600;
}
