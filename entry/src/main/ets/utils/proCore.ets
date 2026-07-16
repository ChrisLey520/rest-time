// 订阅状态：本地骨架。IAP 上线后由支付回调/收据校验写入,当前仅体验期状态。
export type ProPlan = 'none' | 'monthly' | 'yearly' | 'lifetime';
export type ProSource = 'none' | 'iap' | 'promo';

export interface ProState {
  plan: ProPlan;
  // 到期时间戳(ms)。lifetime 忽略此字段;none 恒为 0。
  expiresAt: number;
  source: ProSource;
  // 最近一次校验时间,用于展示和后续收据复核。
  verifiedAt: number;
}

export function createFreeProState(): ProState {
  return {
    plan: 'none',
    expiresAt: 0,
    source: 'none',
    verifiedAt: 0
  };
}

export function normalizeProState(state?: ProState): ProState {
  if (!state) {
    return createFreeProState();
  }

  const plan: ProPlan = state.plan === 'monthly' || state.plan === 'yearly' || state.plan === 'lifetime'
    ? state.plan
    : 'none';
  return {
    plan,
    expiresAt: plan === 'none' ? 0 : Math.max(0, Math.floor(state.expiresAt ? state.expiresAt : 0)),
    source: state.source === 'iap' || state.source === 'promo' ? state.source : 'none',
    verifiedAt: Math.max(0, Math.floor(state.verifiedAt ? state.verifiedAt : 0))
  };
}

export function isProActive(state: ProState, now: number): boolean {
  if (state.plan === 'none') {
    return false;
  }

  if (state.plan === 'lifetime') {
    return true;
  }

  return state.expiresAt > now;
}

export function proStatusText(state: ProState, now: number): string {
  if (!isProActive(state, now)) {
    return '体验期 · 以下能力当前全部免费开放';
  }

  if (state.plan === 'lifetime') {
    return '已订阅 · 永久版';
  }

  const date = new Date(state.expiresAt);
  const label = state.plan === 'yearly' ? '年度订阅' : '月度订阅';
  return `已订阅 · ${label}，${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()} 到期`;
}

export function proBadgeText(state: ProState, now: number): string {
  return isProActive(state, now) ? 'Pro' : '体验期';
}
