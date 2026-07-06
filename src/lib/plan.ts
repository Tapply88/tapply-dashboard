export type Plan = 'trial' | 'starter' | 'pro' | 'multi_outlet';

export type PlanInfo = {
  plan: Plan;
  plan_expires_at: string | null;
};

/** Trial masih dianggap "Pro" sampai tanggal expired-nya. */
export function isProActive(info: PlanInfo | null | undefined): boolean {
  if (!info) return false;
  if (info.plan === 'pro' || info.plan === 'multi_outlet') return true;
  if (info.plan === 'trial') {
    if (!info.plan_expires_at) return false;
    return new Date(info.plan_expires_at) > new Date();
  }
  return false;
}

export function planLabel(info: PlanInfo | null | undefined): string {
  if (!info) return 'Unknown';
  if (info.plan === 'trial') {
    const active = isProActive(info);
    return active ? 'Trial (Pro features)' : 'Trial Expired';
  }
  if (info.plan === 'starter') return 'Starter';
  if (info.plan === 'pro') return 'Pro';
  if (info.plan === 'multi_outlet') return 'Multi-Outlet';
  return 'Unknown';
}

export function daysRemaining(planExpiresAt: string | null): number | null {
  if (!planExpiresAt) return null;
  const diff = new Date(planExpiresAt).getTime() - Date.now();
  return Math.max(0, Math.ceil(diff / 86400000));
}
