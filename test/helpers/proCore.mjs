export function createFreeProState() {
  return {
    plan: 'none',
    expiresAt: 0,
    source: 'none',
    verifiedAt: 0
  };
}

export function normalizeProState(state) {
  if (!state) {
    return createFreeProState();
  }

  const plan = state.plan === 'monthly' || state.plan === 'yearly' || state.plan === 'lifetime'
    ? state.plan
    : 'none';
  return {
    plan,
    expiresAt: plan === 'none' ? 0 : Math.max(0, Math.floor(state.expiresAt || 0)),
    source: state.source === 'iap' || state.source === 'promo' ? state.source : 'none',
    verifiedAt: Math.max(0, Math.floor(state.verifiedAt || 0))
  };
}

export function isProActive(state, now) {
  if (state.plan === 'none') {
    return false;
  }

  if (state.plan === 'lifetime') {
    return true;
  }

  return state.expiresAt > now;
}

export function proStatusText(state, now) {
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

export function proBadgeText(state, now) {
  return isProActive(state, now) ? 'Pro' : '体验期';
}
