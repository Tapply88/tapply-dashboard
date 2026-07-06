cat > supabase/migration_016_plans_trial.sql << 'MIGEOF'
-- Sistem paket & trial. Plan baru selalu mulai dari trial 14 hari (full akses
-- Pro), abis itu turun ke starter kalau gak di-upgrade manual. Admin Tapply
-- (kamu) nge-upgrade customer manual dari Supabase Table Editor pas mereka
-- transfer/bayar di luar sistem (billing manual dulu, belum ada payment gateway).

alter table businesses
  add column if not exists plan text default 'trial', -- 'trial' | 'starter' | 'pro' | 'multi_outlet'
  add column if not exists plan_expires_at timestamptz default (now() + interval '14 days'),
  add column if not exists trial_started_at timestamptz default now();
MIGEOF

cat > src/lib/plan.ts << 'PLANEOF'
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
PLANEOF

cat > src/components/UpgradeLock.tsx << 'LOCKEOF'
import Link from 'next/link';

export function UpgradeLock({ feature }: { feature: string }) {
  return (
    <div className="receipt-card max-w-md text-center py-12">
      <p className="text-3xl mb-3">🔒</p>
      <p className="font-semibold text-navy mb-2">{feature} is a Pro feature</p>
      <p className="text-sm text-ink/60 mb-6">
        Upgrade your plan to unlock this, or contact us to arrange payment.
      </p>
      <div className="flex gap-3 justify-center">
        <Link href="/pricing" className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
          See Plans
        </Link>
        <Link href="/contact" className="rounded-full border border-navy text-navy px-5 py-2.5 text-sm font-medium">
          Contact Us
        </Link>
      </div>
    </div>
  );
}
LOCKEOF

cat > src/app/dashboard/members/page.tsx << 'MEMEOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { isProActive, type PlanInfo } from '@/lib/plan';
import { UpgradeLock } from '@/components/UpgradeLock';

type Member = {
  id: string;
  name: string;
  phone: string;
  points: number;
  birth_date: string | null;
};

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

export default function MembersPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [members, setMembers] = useState<Member[]>([]);
  const [redemptionValue, setRedemptionValue] = useState(100);
  const [redemptionMultiple, setRedemptionMultiple] = useState(300);
  const [planInfo, setPlanInfo] = useState<PlanInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Member | null>(null);
  const [form, setForm] = useState({ name: '', phone: '', points: '0', birth_date: '' });
  const [redeemTarget, setRedeemTarget] = useState<Member | null>(null);
  const [redeemPoints, setRedeemPoints] = useState('');

  const loadMembers = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (link) {
        setBusinessId(link.business_id);
        const { data: business } = await supabase.from('businesses').select('points_redemption_value, points_redemption_multiple, plan, plan_expires_at').eq('id', link.business_id).single();
        if (business?.points_redemption_value) setRedemptionValue(business.points_redemption_value);
        if (business?.points_redemption_multiple) setRedemptionMultiple(business.points_redemption_multiple);
        if (business) setPlanInfo({ plan: business.plan, plan_expires_at: business.plan_expires_at });
      }
    }
    const { data } = await supabase.from('members').select('*').order('name');
    setMembers(data ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadMembers();
  }, [loadMembers]);

  function openAddForm() {
    setEditing(null);
    setForm({ name: '', phone: '', points: '0', birth_date: '' });
    setShowForm(true);
  }

  function openEditForm(m: Member) {
    setEditing(m);
    setForm({ name: m.name, phone: m.phone, points: String(m.points), birth_date: m.birth_date ?? '' });
    setShowForm(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    const payload = {
      name: form.name.trim(),
      phone: form.phone.trim(),
      points: Number(form.points) || 0,
      birth_date: form.birth_date || null,
    };
    if (!payload.name || !payload.phone) return;

    if (editing) {
      await supabase.from('members').update(payload).eq('id', editing.id);
    } else {
      if (!businessId) return;
      await supabase.from('members').insert({ ...payload, business_id: businessId });
    }
    setShowForm(false);
    loadMembers();
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this member?')) return;
    await supabase.from('members').delete().eq('id', id);
    loadMembers();
  }

  function openRedeemModal(m: Member) {
    setRedeemTarget(m);
    setRedeemPoints('');
  }

  async function confirmRedeem() {
    if (!redeemTarget || !businessId) return;
    const points = Number(redeemPoints) || 0;
    if (points <= 0 || points > redeemTarget.points) {
      alert('Enter a valid number of points (up to what the member has).');
      return;
    }
    if (redemptionMultiple > 0 && points % redemptionMultiple !== 0) {
      alert(`Points must be redeemed in multiples of ${redemptionMultiple}.`);
      return;
    }
    const valueRupiah = points * redemptionValue;
    await supabase.from('members').update({ points: redeemTarget.points - points }).eq('id', redeemTarget.id);
    await supabase.from('point_redemptions').insert({
      business_id: businessId,
      member_id: redeemTarget.id,
      points_redeemed: points,
      value_rupiah: valueRupiah,
    });
    setRedeemTarget(null);
    loadMembers();
  }

  if (!loading && planInfo && !isProActive(planInfo)) {
    return (
      <div>
        <p className="label-eyebrow mb-2">Customers</p>
        <h1 className="text-2xl font-semibold mb-8">Members</h1>
        <UpgradeLock feature="Member accounts & loyalty points" />
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-8">
        <div>
          <p className="label-eyebrow mb-2">Customers</p>
          <h1 className="text-2xl font-semibold">Members</h1>
        </div>
        <button
          onClick={openAddForm}
          className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium hover:bg-navy-soft transition-colors"
        >
          + Add Member
        </button>
      </div>

      <div className="receipt-card max-w-lg mb-8 !bg-sage-light !border-sage/30">
        <p className="text-sm text-ink/70">
          Members sync automatically with the cashier app. Redemption rate is currently{' '}
          <strong>{formatRupiah(redemptionValue)} per point</strong>, redeemed in multiples of{' '}
          <strong>{redemptionMultiple}</strong> — change it in Settings.
        </p>
      </div>

      {showForm && (
        <form onSubmit={handleSave} className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">{editing ? 'Edit Member' : 'New Member'}</p>
          <input
            required
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Member name"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <input
            required
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            placeholder="Phone number"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <div className="grid grid-cols-2 gap-3">
            <input
              type="number"
              value={form.points}
              onChange={(e) => setForm({ ...form, points: e.target.value })}
              placeholder="Points"
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
            <div>
              <input
                type="date"
                value={form.birth_date}
                onChange={(e) => setForm({ ...form, birth_date: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
              <p className="text-xs text-ink/40 mt-1">Birthday (optional)</p>
            </div>
          </div>
          <div className="flex gap-3">
            <button type="submit" className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
              Save
            </button>
            <button
              type="button"
              onClick={() => setShowForm(false)}
              className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium"
            >
              Cancel
            </button>
          </div>
        </form>
      )}

      {redeemTarget && (
        <div className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">Redeem Points — {redeemTarget.name}</p>
          <p className="text-sm text-ink/60">
            Balance: <strong>{redeemTarget.points} points</strong> ({formatRupiah(redeemTarget.points * redemptionValue)})
          </p>
          <input
            type="number"
            value={redeemPoints}
            onChange={(e) => setRedeemPoints(e.target.value)}
            placeholder="Points to redeem"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          {redeemPoints && Number(redeemPoints) > 0 && (
            <p className="text-sm text-sage">
              = {formatRupiah(Number(redeemPoints) * redemptionValue)} discount value
            </p>
          )}
          <div className="flex gap-3">
            <button onClick={confirmRedeem} className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
              Confirm Redemption
            </button>
            <button onClick={() => setRedeemTarget(null)} className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium">
              Cancel
            </button>
          </div>
        </div>
      )}

      {loading ? (
        <p className="text-sm text-ink/50">Loading...</p>
      ) : members.length === 0 ? (
        <div className="receipt-card max-w-lg text-center py-10">
          <p className="text-ink/60">No members yet.</p>
        </div>
      ) : (
        <div className="receipt-card overflow-hidden !p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-grey-light text-left">
                <th className="label-eyebrow px-5 py-3 font-medium">Name</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Phone</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Birthday</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Points</th>
                <th className="px-5 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {members.map((m) => (
                <tr key={m.id} className="border-b border-grey-light last:border-0">
                  <td className="px-5 py-3 font-medium">{m.name}</td>
                  <td className="px-5 py-3 text-ink/60">{m.phone}</td>
                  <td className="px-5 py-3 text-ink/60 text-xs">
                    {m.birth_date ? new Date(m.birth_date).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' }) : '—'}
                  </td>
                  <td className="px-5 py-3 figure">{m.points}</td>
                  <td className="px-5 py-3 text-right whitespace-nowrap">
                    <button onClick={() => openRedeemModal(m)} disabled={m.points <= 0} className="text-sage text-xs font-medium mr-3 disabled:opacity-30">
                      Redeem
                    </button>
                    <button onClick={() => openEditForm(m)} className="text-navy text-xs font-medium mr-3">
                      Edit
                    </button>
                    <button onClick={() => handleDelete(m.id)} className="text-rust text-xs font-medium">
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
MEMEOF

cat > src/app/dashboard/page.tsx << 'DASHEOF'
'use client';

import { useEffect, useState, useCallback, useMemo } from 'react';
import { createClient } from '@/lib/supabase/client';
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { ReceiptStatCard } from '@/components/ReceiptStatCard';
import { useI18n } from '@/lib/i18n';
import { isProActive, type PlanInfo } from '@/lib/plan';
import { UpgradeLock } from '@/components/UpgradeLock';

type Period = 'today' | 'week' | 'month' | 'custom';

type TxItem = { productId: string; productName: string; qty: number };
type Tx = { id: string; total: number; payment_method: string; items: TxItem[]; created_at: string };
type ProductInfo = { id: string; category: string };

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

function toDateInputValue(d: Date) {
  return d.toISOString().slice(0, 10);
}

function dayKey(iso: string) {
  return iso.slice(0, 10);
}

function getPresetRange(period: Period): { from: Date; to: Date } {
  const now = new Date();
  const to = new Date(now);
  to.setHours(23, 59, 59, 999);
  const from = new Date(now);
  if (period === 'today') {
    from.setHours(0, 0, 0, 0);
  } else if (period === 'week') {
    from.setDate(now.getDate() - 6);
    from.setHours(0, 0, 0, 0);
  } else if (period === 'month') {
    from.setDate(now.getDate() - 29);
    from.setHours(0, 0, 0, 0);
  }
  return { from, to };
}

const CHART_NAVY = '#092762';
const CHART_SAGE = '#5B8266';
const CHART_RUST = '#B54834';

export default function DashboardHomePage() {
  const supabase = createClient();
  const { t } = useI18n();
  const [businessName, setBusinessName] = useState('');
  const [period, setPeriod] = useState<Period>('today');
  const [customFrom, setCustomFrom] = useState(toDateInputValue(new Date(Date.now() - 6 * 86400000)));
  const [customTo, setCustomTo] = useState(toDateInputValue(new Date()));
  const [transactions, setTransactions] = useState<Tx[]>([]);
  const [previousTransactions, setPreviousTransactions] = useState<Tx[]>([]);
  const [products, setProducts] = useState<ProductInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [planInfo, setPlanInfo] = useState<PlanInfo | null>(null);
  const isPro = isProActive(planInfo);

  const range = useMemo(() => {
    if (period === 'custom') {
      return { from: new Date(customFrom + 'T00:00:00'), to: new Date(customTo + 'T23:59:59') };
    }
    return getPresetRange(period);
  }, [period, customFrom, customTo]);

  const previousRange = useMemo(() => {
    const spanMs = range.to.getTime() - range.from.getTime();
    const prevTo = new Date(range.from.getTime() - 1);
    const prevFrom = new Date(prevTo.getTime() - spanMs);
    return { from: prevFrom, to: prevTo };
  }, [range]);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);

    if (period === 'custom') {
      const days = (range.to.getTime() - range.from.getTime()) / 86400000;
      if (days > 30) {
        setError('Rentang maksimal 30 hari. Persempit pilihan tanggalnya ya.');
        setLoading(false);
        return;
      }
      if (days < 0) {
        setError('Tanggal mulai harus sebelum tanggal selesai.');
        setLoading(false);
        return;
      }
      const oneYearAgo = new Date();
      oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);
      if (range.from < oneYearAgo) {
        setError('Data cuma bisa dilihat sampai 1 tahun ke belakang.');
        setLoading(false);
        return;
      }
    }

    const [{ data: current }, { data: previous }, { data: productData }] = await Promise.all([
      supabase
        .from('transactions')
        .select('id, total, payment_method, items, created_at')
        .eq('status', 'paid')
        .gte('created_at', range.from.toISOString())
        .lte('created_at', range.to.toISOString()),
      supabase
        .from('transactions')
        .select('id, total, payment_method, items, created_at')
        .eq('status', 'paid')
        .gte('created_at', previousRange.from.toISOString())
        .lte('created_at', previousRange.to.toISOString()),
      supabase.from('products').select('id, category'),
    ]);

    setTransactions((current as Tx[]) ?? []);
    setPreviousTransactions((previous as Tx[]) ?? []);
    setProducts((productData as ProductInfo[]) ?? []);
    setLoading(false);
  }, [supabase, range, previousRange, period]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  useEffect(() => {
    async function loadBusiness() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (!link) return;
      const { data: business } = await supabase.from('businesses').select('name, plan, plan_expires_at').eq('id', link.business_id).single();
      if (business) {
        setBusinessName(business.name);
        setPlanInfo({ plan: business.plan, plan_expires_at: business.plan_expires_at });
      }
    }
    loadBusiness();
  }, [supabase]);

  const totalRevenue = transactions.reduce((sum, t) => sum + (t.total ?? 0), 0);
  const previousRevenue = previousTransactions.reduce((sum, t) => sum + (t.total ?? 0), 0);
  const revenueChangePct = previousRevenue > 0 ? ((totalRevenue - previousRevenue) / previousRevenue) * 100 : null;
  const txCount = transactions.length;

  const byPayment = new Map<string, number>();
  for (const t of transactions) {
    byPayment.set(t.payment_method, (byPayment.get(t.payment_method) ?? 0) + (t.total ?? 0));
  }
  const paymentData = Array.from(byPayment.entries())
    .map(([method, amount]) => ({ method: method.replace(/_/g, ' '), amount }))
    .sort((a, b) => b.amount - a.amount);

  const productQty = new Map<string, number>();
  const productIdByName = new Map<string, string>();
  for (const t of transactions) {
    for (const item of t.items ?? []) {
      productQty.set(item.productName, (productQty.get(item.productName) ?? 0) + (item.qty ?? 0));
      if (item.productId) productIdByName.set(item.productName, item.productId);
    }
  }
  const topProducts = Array.from(productQty.entries())
    .map(([name, qty]) => ({ name, qty }))
    .sort((a, b) => b.qty - a.qty)
    .slice(0, 10);

  const categoryById = new Map(products.map((p) => [p.id, p.category]));
  const byCategory = new Map<string, number>();
  for (const [name, qty] of productQty.entries()) {
    const id = productIdByName.get(name);
    const category = (id && categoryById.get(id)) || 'Lainnya';
    byCategory.set(category, (byCategory.get(category) ?? 0) + qty);
  }
  const categoryData = Array.from(byCategory.entries())
    .map(([category, qty]) => ({ category, qty }))
    .sort((a, b) => b.qty - a.qty);

  const byDay = new Map<string, number>();
  for (const t of transactions) {
    const key = dayKey(t.created_at);
    byDay.set(key, (byDay.get(key) ?? 0) + (t.total ?? 0));
  }
  const dailyTrend = Array.from(byDay.entries())
    .map(([date, total]) => ({ date: date.slice(5), total }))
    .sort((a, b) => (a.date > b.date ? 1 : -1));

  function exportCsv() {
    const header = 'Date,Payment Method,Items,Total\n';
    const rows = transactions
      .map((t) => {
        const itemsSummary = (t.items ?? []).map((i) => `${i.productName} x${i.qty}`).join('; ');
        const date = new Date(t.created_at).toLocaleString('id-ID');
        return `"${date}","${t.payment_method}","${itemsSummary.replace(/"/g, "'")}",${t.total}`;
      })
      .join('\n');
    const blob = new Blob([header + rows], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `tapply-sales-${toDateInputValue(range.from)}-to-${toDateInputValue(range.to)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div>
      <p className="label-eyebrow mb-2">{businessName || 'Ringkasan'}</p>
      <h1 className="text-2xl font-semibold mb-6">{t('sales_report')}</h1>

      <div className="flex flex-wrap items-center gap-2 mb-8">
        {(['today', 'week', 'month', 'custom'] as Period[]).map((p) => {
          const locked = p !== 'today' && !isPro;
          return (
            <button
              key={p}
              onClick={() => (locked ? undefined : setPeriod(p))}
              disabled={locked}
              title={locked ? 'Upgrade to Pro to view this period' : undefined}
              className={`rounded-full px-4 py-2 text-sm font-medium transition-colors ${
                period === p ? 'bg-navy text-white' : 'border border-grey text-navy hover:bg-navy-50'
              } ${locked ? 'opacity-40 cursor-not-allowed' : ''}`}
            >
              {p === 'today' ? t('today') : p === 'week' ? t('seven_days') : p === 'month' ? t('thirty_days') : t('pick_period')}
              {locked && ' 🔒'}
            </button>
          );
        })}
        {period === 'custom' && (
          <div className="flex items-center gap-2 ml-2">
            <input
              type="date"
              value={customFrom}
              onChange={(e) => setCustomFrom(e.target.value)}
              className="rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
            <span className="text-ink/40 text-sm">–</span>
            <input
              type="date"
              value={customTo}
              onChange={(e) => setCustomTo(e.target.value)}
              className="rounded-lg border border-grey px-3 py-2 text-sm focus:border-navy outline-none"
            />
          </div>
        )}
        <button
          onClick={exportCsv}
          disabled={transactions.length === 0 || !isPro}
          title={!isPro ? 'Upgrade to Pro to export' : undefined}
          className="ml-auto rounded-full border border-navy text-navy px-4 py-2 text-sm font-medium hover:bg-navy-50 transition-colors disabled:opacity-40"
        >
          {t('export_csv')}
        </button>
      </div>

      {error && (
        <div className="receipt-card max-w-lg mb-8 !bg-rust-light !border-rust/30">
          <p className="text-sm text-rust">{error}</p>
        </div>
      )}

      {loading ? (
        <p className="text-sm text-ink/50">Memuat...</p>
      ) : (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-5 mb-10">
            <ReceiptStatCard
              label={t('total_sales')}
              value={formatRupiah(totalRevenue)}
              sublabel={
                revenueChangePct === null || !isPro
                  ? `${txCount} transaksi`
                  : `${revenueChangePct >= 0 ? '+' : ''}${revenueChangePct.toFixed(0)}% dari periode sebelumnya • ${txCount} transaksi`
              }
              accent={isPro && revenueChangePct !== null && revenueChangePct < 0 ? 'rust' : 'navy'}
            />
            <ReceiptStatCard
              label={t('avg_per_transaction')}
              value={formatRupiah(txCount > 0 ? Math.round(totalRevenue / txCount) : 0)}
              accent="sage"
            />
          </div>

          {isPro ? (
            <div className="receipt-card mb-8">
              <p className="label-eyebrow mb-4">{t('daily_sales_trend')}</p>
              {dailyTrend.length < 2 ? (
                <p className="text-sm text-ink/50">Butuh minimal 2 hari data buat nampilin tren.</p>
              ) : (
                <ResponsiveContainer width="100%" height={220}>
                  <LineChart data={dailyTrend}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                    <YAxis tickFormatter={(v) => formatRupiah(v)} tick={{ fontSize: 10 }} width={70} />
                    <Tooltip formatter={(v: number) => [formatRupiah(v), 'Penjualan']} />
                    <Line type="monotone" dataKey="total" stroke={CHART_NAVY} strokeWidth={2} dot={{ r: 3 }} />
                  </LineChart>
                </ResponsiveContainer>
              )}
            </div>
          ) : (
            <div className="mb-8">
              <UpgradeLock feature="Daily sales trends & period comparison" />
            </div>
          )}

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <div className="receipt-card">
              <p className="label-eyebrow mb-4">{t('best_selling_products')}</p>
              {topProducts.length === 0 ? (
                <p className="text-sm text-ink/50">{t('no_transactions_period')}</p>
              ) : (
                <ResponsiveContainer width="100%" height={Math.max(200, topProducts.length * 34)}>
                  <BarChart data={topProducts} layout="vertical" margin={{ left: 20 }}>
                    <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                    <XAxis type="number" allowDecimals={false} tick={{ fontSize: 11 }} />
                    <YAxis type="category" dataKey="name" width={110} tick={{ fontSize: 11 }} />
                    <Tooltip formatter={(v: number) => [`${v} unit`, 'Terjual']} />
                    <Bar dataKey="qty" fill={CHART_NAVY} radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>

            <div className="receipt-card">
              <p className="label-eyebrow mb-4">{t('sales_by_payment')}</p>
              {paymentData.length === 0 ? (
                <p className="text-sm text-ink/50">{t('no_transactions_period')}</p>
              ) : (
                <ResponsiveContainer width="100%" height={Math.max(200, paymentData.length * 40)}>
                  <BarChart data={paymentData} layout="vertical" margin={{ left: 20 }}>
                    <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                    <XAxis type="number" tickFormatter={(v) => formatRupiah(v)} tick={{ fontSize: 10 }} />
                    <YAxis type="category" dataKey="method" width={100} tick={{ fontSize: 11 }} className="capitalize" />
                    <Tooltip formatter={(v: number) => [formatRupiah(v), 'Total']} />
                    <Bar dataKey="amount" fill={CHART_SAGE} radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>
          </div>

          {isPro ? (
            <div className="receipt-card">
              <p className="label-eyebrow mb-4">{t('sales_by_category')}</p>
              {categoryData.length === 0 ? (
                <p className="text-sm text-ink/50">{t('no_transactions_period')}</p>
              ) : (
                <ResponsiveContainer width="100%" height={Math.max(160, categoryData.length * 40)}>
                  <BarChart data={categoryData} layout="vertical" margin={{ left: 20 }}>
                    <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                    <XAxis type="number" allowDecimals={false} tick={{ fontSize: 11 }} />
                    <YAxis type="category" dataKey="category" width={100} tick={{ fontSize: 11 }} />
                    <Tooltip formatter={(v: number) => [`${v} unit`, 'Terjual']} />
                    <Bar dataKey="qty" fill={CHART_RUST} radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>
          ) : (
            <UpgradeLock feature="Sales by category" />
          )}
        </>
      )}
    </div>
  );
}
DASHEOF

cat > src/app/dashboard/products/page.tsx << 'PRODEOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import Papa from 'papaparse';
import { createClient } from '@/lib/supabase/client';
import { isProActive, type PlanInfo } from '@/lib/plan';
import { UpgradeLock } from '@/components/UpgradeLock';

type Product = {
  id: string;
  name: string;
  price: number;
  category: string;
  stock: number;
  is_active: boolean;
  sku: string | null;
  volume: string | null;
  label_size: string | null;
  show_price_on_label: boolean;
  label_variant: string | null;
  label_addons: string[] | null;
  expiry_date: string | null;
  production_date: string | null;
  image_base64: string | null;
  online_price: number | null;
};

type Variation = { id: string; name: string };
type Addon = { id: string; name: string; price: number };

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

const emptyForm = {
  name: '',
  price: '',
  category: 'General',
  stock: '0',
  sku: '',
  volume: '',
  label_size: '60x40mm',
  show_price_on_label: true,
  label_variant: '',
  label_addons: [] as string[],
  expiry_date: '',
  production_date: '',
  image_base64: '' as string | null,
  online_price: '',
};

export default function ProductsPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [planInfo, setPlanInfo] = useState<PlanInfo | null>(null);
  const isPro = isProActive(planInfo);
  const [products, setProducts] = useState<Product[]>([]);
  const [variations, setVariations] = useState<Variation[]>([]);
  const [addons, setAddons] = useState<Addon[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [showImport, setShowImport] = useState<boolean | 'locked'>(false);
  const [importPreview, setImportPreview] = useState<Record<string, string>[]>([]);
  const [importError, setImportError] = useState<string | null>(null);
  const [importing, setImporting] = useState(false);
  const [editing, setEditing] = useState<Product | null>(null);
  const [form, setForm] = useState(emptyForm);

  const loadData = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (link) {
        setBusinessId(link.business_id);
        const { data: business } = await supabase.from('businesses').select('plan, plan_expires_at').eq('id', link.business_id).single();
        if (business) setPlanInfo({ plan: business.plan, plan_expires_at: business.plan_expires_at });
      }
    }
    const [{ data: productData }, { data: variationData }, { data: addonData }] = await Promise.all([
      supabase.from('products').select('*').order('name'),
      supabase.from('variations').select('id, name').order('sort_order'),
      supabase.from('addons').select('id, name, price').order('sort_order'),
    ]);
    setProducts(productData ?? []);
    setVariations(variationData ?? []);
    setAddons(addonData ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  function handleImportFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setImportError(null);
    Papa.parse<Record<string, string>>(file, {
      header: true,
      skipEmptyLines: true,
      complete: (results) => {
        const rows = results.data.filter((r) => r.name && r.name.trim());
        if (rows.length === 0) {
          setImportError('No valid rows found. Make sure the CSV has a "name" column.');
          setImportPreview([]);
          return;
        }
        setImportPreview(rows);
      },
      error: (err) => setImportError(err.message),
    });
  }

  async function confirmImport() {
    if (!businessId || importPreview.length === 0) return;
    setImporting(true);
    const rows = importPreview.map((r) => ({
      business_id: businessId,
      name: r.name?.trim(),
      price: Number(r.price) || 0,
      category: r.category?.trim() || 'General',
      stock: Number(r.stock) || 0,
      sku: r.sku?.trim() || null,
      volume: r.volume?.trim() || null,
    }));
    const { error } = await supabase.from('products').insert(rows);
    setImporting(false);
    if (error) {
      setImportError(error.message);
      return;
    }
    setShowImport(false);
    setImportPreview([]);
    loadData();
  }

  function downloadTemplate() {
    const csv = 'name,price,category,stock,sku,volume\nKunyit Asam,15000,Jamu,50,KA-001,250ml\n';
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'tapply-menu-template.csv';
    a.click();
    URL.revokeObjectURL(url);
  }

  function openAddForm() {
    setEditing(null);
    setForm(emptyForm);
    setShowForm(true);
  }

  function openEditForm(p: Product) {
    setEditing(p);
    setForm({
      name: p.name,
      price: String(p.price),
      category: p.category,
      stock: String(p.stock),
      sku: p.sku ?? '',
      volume: p.volume ?? '',
      label_size: p.label_size ?? '60x40mm',
      show_price_on_label: p.show_price_on_label ?? true,
      label_variant: p.label_variant ?? '',
      label_addons: p.label_addons ?? [],
      expiry_date: p.expiry_date ?? '',
      production_date: p.production_date ?? '',
      image_base64: p.image_base64,
      online_price: p.online_price != null ? String(p.online_price) : '',
    });
    setShowForm(true);
  }

  function handlePhotoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      const base64 = result.split(',')[1];
      setForm((f) => ({ ...f, image_base64: base64 }));
    };
    reader.readAsDataURL(file);
  }

  function toggleAddon(name: string) {
    setForm((f) => ({
      ...f,
      label_addons: f.label_addons.includes(name) ? f.label_addons.filter((a) => a !== name) : [...f.label_addons, name],
    }));
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    const payload = {
      name: form.name.trim(),
      price: Number(form.price) || 0,
      category: form.category.trim() || 'General',
      stock: Number(form.stock) || 0,
      sku: form.sku.trim() || null,
      volume: form.volume.trim() || null,
      label_size: form.label_size,
      show_price_on_label: form.show_price_on_label,
      label_variant: form.label_variant || null,
      label_addons: form.label_addons,
      expiry_date: form.expiry_date || null,
      production_date: form.production_date || null,
      image_base64: form.image_base64 || null,
      online_price: form.online_price.trim() === '' ? null : Number(form.online_price),
    };
    if (!payload.name) return;

    if (editing) {
      await supabase.from('products').update(payload).eq('id', editing.id);
    } else {
      if (!businessId) return;
      await supabase.from('products').insert({ ...payload, business_id: businessId });
    }
    setShowForm(false);
    loadData();
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this product?')) return;
    await supabase.from('products').delete().eq('id', id);
    loadData();
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-8">
        <div>
          <p className="label-eyebrow mb-2">Catalog</p>
          <h1 className="text-2xl font-semibold">Products</h1>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => (isPro ? setShowImport(true) : setShowImport('locked'))}
            className="rounded-full border border-navy text-navy px-5 py-2.5 text-sm font-medium hover:bg-navy-50 transition-colors"
          >
            Import CSV {!isPro && '🔒'}
          </button>
          <button
            onClick={openAddForm}
            className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium hover:bg-navy-soft transition-colors"
          >
            + Add Product
          </button>
        </div>
      </div>

      {showImport === 'locked' && (
        <div className="mb-8">
          <UpgradeLock feature="CSV menu import" />
        </div>
      )}

      {showImport === true && (
        <div className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">Import Menu from CSV</p>
          <p className="text-xs text-ink/50">
            Columns: <code>name</code> (required), <code>price</code>, <code>category</code>, <code>stock</code>,{' '}
            <code>sku</code>, <code>volume</code>.{' '}
            <button type="button" onClick={downloadTemplate} className="text-navy underline">
              Download template
            </button>
          </p>
          <input type="file" accept=".csv" onChange={handleImportFile} className="text-sm" />
          {importError && <p className="text-rust text-sm">{importError}</p>}
          {importPreview.length > 0 && (
            <div className="max-h-48 overflow-y-auto border border-grey rounded-lg p-2 text-xs">
              <p className="font-medium mb-2">{importPreview.length} product(s) ready to import:</p>
              {importPreview.slice(0, 10).map((r, i) => (
                <p key={i} className="text-ink/60">
                  {r.name} — {r.price ? formatRupiah(Number(r.price)) : 'Rp 0'}
                </p>
              ))}
              {importPreview.length > 10 && <p className="text-ink/40">...and {importPreview.length - 10} more</p>}
            </div>
          )}
          <div className="flex gap-3">
            <button
              onClick={confirmImport}
              disabled={importPreview.length === 0 || importing}
              className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium disabled:opacity-40"
            >
              {importing ? 'Importing...' : `Import ${importPreview.length || ''} Product(s)`}
            </button>
            <button
              type="button"
              onClick={() => {
                setShowImport(false);
                setImportPreview([]);
                setImportError(null);
              }}
              className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {showForm && (
        <form onSubmit={handleSave} className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">{editing ? 'Edit Product' : 'New Product'}</p>

          <div className="flex items-center gap-4">
            <div className="w-20 h-20 rounded-lg bg-cream border border-grey flex items-center justify-center overflow-hidden shrink-0">
              {form.image_base64 ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={`data:image/jpeg;base64,${form.image_base64}`} alt="" className="w-full h-full object-cover" />
              ) : (
                <span className="text-xs text-ink/40">No photo</span>
              )}
            </div>
            <input type="file" accept="image/*" onChange={handlePhotoChange} className="text-xs" />
          </div>

          <input
            required
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Product name"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <div className="grid grid-cols-2 gap-3">
            <input
              required
              type="number"
              value={form.price}
              onChange={(e) => setForm({ ...form, price: e.target.value })}
              placeholder="Price (Rp)"
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
            <input
              type="number"
              value={form.stock}
              onChange={(e) => setForm({ ...form, stock: e.target.value })}
              placeholder="Stock"
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <input
            value={form.category}
            onChange={(e) => setForm({ ...form, category: e.target.value })}
            placeholder="Category"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />

          <div className="grid grid-cols-2 gap-3 pt-2 border-t border-grey-light">
            <div>
              <label className="label-eyebrow block mb-1.5 mt-3">SKU</label>
              <input
                value={form.sku}
                onChange={(e) => setForm({ ...form, sku: e.target.value })}
                placeholder="Auto-generated if blank"
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
            <div>
              <label className="label-eyebrow block mb-1.5 mt-3">Volume/Size</label>
              <input
                value={form.volume}
                onChange={(e) => setForm({ ...form, volume: e.target.value })}
                placeholder="e.g. 250ml"
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
          </div>

          <div>
            <label className="label-eyebrow block mb-1.5">Label Size</label>
            <select
              value={form.label_size}
              onChange={(e) => setForm({ ...form, label_size: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            >
              <option value="60x40mm">60x40mm</option>
              <option value="50x30mm">50x30mm</option>
              <option value="40x30mm">40x30mm</option>
            </select>
          </div>

          {variations.length > 0 && (
            <div>
              <label className="label-eyebrow block mb-1.5">Default Label Variant</label>
              <select
                value={form.label_variant}
                onChange={(e) => setForm({ ...form, label_variant: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              >
                <option value="">None</option>
                {variations.map((v) => (
                  <option key={v.id} value={v.name}>{v.name}</option>
                ))}
              </select>
            </div>
          )}

          {addons.length > 0 && (
            <div>
              <p className="label-eyebrow mb-2">Default Label Add-ons</p>
              <div className="flex flex-wrap gap-2">
                {addons.map((a) => (
                  <label key={a.id} className="flex items-center gap-1.5 text-xs border border-grey rounded-full px-3 py-1.5 cursor-pointer">
                    <input type="checkbox" checked={form.label_addons.includes(a.name)} onChange={() => toggleAddon(a.name)} />
                    {a.name}{a.price > 0 ? ` (+${formatRupiah(a.price)})` : ''}
                  </label>
                ))}
              </div>
            </div>
          )}

          <div>
            <label className="label-eyebrow block mb-1.5">Online Order Price (optional)</label>
            <input
              type="number"
              value={form.online_price}
              onChange={(e) => setForm({ ...form, online_price: e.target.value })}
              placeholder="Leave blank to use the regular price above"
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
            <p className="text-xs text-ink/50 mt-1">Used when the sales type is any Online Order (GoFood, GrabFood, ShopeeFood, etc).</p>
          </div>

          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.show_price_on_label}
              onChange={(e) => setForm({ ...form, show_price_on_label: e.target.checked })}
            />
            Show price on printed label
          </label>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label-eyebrow block mb-1.5">Production Date</label>
              <input
                type="date"
                value={form.production_date}
                onChange={(e) => setForm({ ...form, production_date: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
            <div>
              <label className="label-eyebrow block mb-1.5">Expiry Date</label>
              <input
                type="date"
                value={form.expiry_date}
                onChange={(e) => setForm({ ...form, expiry_date: e.target.value })}
                className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
              />
            </div>
          </div>

          <div className="flex gap-3 pt-2">
            <button type="submit" className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
              Save
            </button>
            <button
              type="button"
              onClick={() => setShowForm(false)}
              className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium"
            >
              Cancel
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <p className="text-sm text-ink/50">Loading...</p>
      ) : products.length === 0 ? (
        <div className="receipt-card max-w-lg text-center py-10">
          <p className="text-ink/60">No products yet. Add your first one.</p>
        </div>
      ) : (
        <div className="receipt-card overflow-hidden !p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-grey-light text-left">
                <th className="label-eyebrow px-5 py-3 font-medium">Name</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Category</th>
                <th className="label-eyebrow px-5 py-3 font-medium">SKU</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Price</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Stock</th>
                <th className="px-5 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {products.map((p) => (
                <tr key={p.id} className="border-b border-grey-light last:border-0">
                  <td className="px-5 py-3 font-medium">{p.name}</td>
                  <td className="px-5 py-3 text-ink/60">{p.category}</td>
                  <td className="px-5 py-3 figure text-xs">{p.sku || '—'}</td>
                  <td className="px-5 py-3 figure">{formatRupiah(p.price)}</td>
                  <td className="px-5 py-3">
                    <span className={p.stock <= 5 ? 'text-rust font-medium' : ''}>{p.stock}</span>
                  </td>
                  <td className="px-5 py-3 text-right">
                    <button onClick={() => openEditForm(p)} className="text-navy text-xs font-medium mr-3">
                      Edit
                    </button>
                    <button onClick={() => handleDelete(p.id)} className="text-rust text-xs font-medium">
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
PRODEOF

cat > src/app/dashboard/staff/page.tsx << 'STAFFEOF'
'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { hashPin } from '@/lib/hash';
import { isProActive, type PlanInfo } from '@/lib/plan';
import { UpgradeLock } from '@/components/UpgradeLock';

type Staff = {
  id: string;
  name: string;
  role: 'cashier' | 'supervisor';
  pin: string;
  active: boolean;
};

const emptyForm = { name: '', role: 'cashier' as 'cashier' | 'supervisor', pin: '', active: true };

export default function StaffPage() {
  const supabase = createClient();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [planInfo, setPlanInfo] = useState<PlanInfo | null>(null);
  const [staff, setStaff] = useState<Staff[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Staff | null>(null);
  const [form, setForm] = useState(emptyForm);

  const loadData = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (link) {
        setBusinessId(link.business_id);
        const { data: business } = await supabase.from('businesses').select('plan, plan_expires_at').eq('id', link.business_id).single();
        if (business) setPlanInfo({ plan: business.plan, plan_expires_at: business.plan_expires_at });
      }
    }
    const { data } = await supabase.from('staff').select('*').order('name');
    setStaff(data ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  function openAddForm() {
    setEditing(null);
    setForm(emptyForm);
    setShowForm(true);
  }

  function openEditForm(s: Staff) {
    setEditing(s);
    // PIN field intentionally left blank — we only ever store a hash, so there's
    // nothing readable to prefill. Leaving it blank keeps the existing PIN unchanged.
    setForm({ name: s.name, role: s.role, pin: '', active: s.active });
    setShowForm(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) return;
    if (!editing && !form.pin.trim()) return; // new staff must set a PIN

    const payload: Record<string, unknown> = { name: form.name.trim(), role: form.role, active: form.active };
    if (form.pin.trim()) {
      payload.pin = await hashPin(form.pin.trim());
    }

    if (editing) {
      await supabase.from('staff').update(payload).eq('id', editing.id);
    } else {
      if (!businessId) return;
      await supabase.from('staff').insert({ ...payload, business_id: businessId });
    }
    setShowForm(false);
    loadData();
  }

  async function handleDelete(id: string) {
    if (!confirm('Remove this staff member?')) return;
    await supabase.from('staff').delete().eq('id', id);
    loadData();
  }

  if (loading) return <p className="text-sm text-ink/50">Loading...</p>;

  const isPro = isProActive(planInfo);
  const staffLimitReached = !isPro && staff.length >= 1;

  return (
    <div className="max-w-2xl">
      <div className="flex items-center justify-between mb-8">
        <div>
          <p className="label-eyebrow mb-2">Team</p>
          <h1 className="text-2xl font-semibold">Staff</h1>
        </div>
        <button
          onClick={() => (staffLimitReached ? undefined : openAddForm())}
          disabled={staffLimitReached}
          title={staffLimitReached ? 'Starter plan is limited to 1 staff account' : undefined}
          className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium hover:bg-navy-soft transition-colors disabled:opacity-40"
        >
          + Add Staff {staffLimitReached && '🔒'}
        </button>
      </div>

      {staffLimitReached && (
        <div className="mb-8">
          <UpgradeLock feature="Multiple staff accounts" />
        </div>
      )}

      <div className="receipt-card mb-8 !bg-sage-light !border-sage/30">
        <p className="text-sm text-ink/70">
          This list syncs to the cashier app automatically. At shift start, cashiers pick their name
          from this list instead of typing it in. Only <strong>Supervisor</strong> PINs can void a
          completed receipt — <strong>Cashier</strong> PINs cannot. PINs are stored as a one-way hash,
          not as plain text — even we can&apos;t read them back, which is why editing a PIN always
          means setting a brand new one.
        </p>
      </div>

      {showForm && (
        <form onSubmit={handleSave} className="receipt-card mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">{editing ? 'Edit Staff' : 'New Staff'}</p>
          <input
            required
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Full name"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <div className="grid grid-cols-2 gap-3">
            <select
              value={form.role}
              onChange={(e) => setForm({ ...form, role: e.target.value as 'cashier' | 'supervisor' })}
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            >
              <option value="cashier">Cashier</option>
              <option value="supervisor">Supervisor</option>
            </select>
            <input
              required={!editing}
              value={form.pin}
              onChange={(e) => setForm({ ...form, pin: e.target.value })}
              placeholder={editing ? 'New PIN (leave blank to keep current)' : 'PIN'}
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={form.active} onChange={(e) => setForm({ ...form, active: e.target.checked })} />
            Active (shows up in the cashier app)
          </label>
          <div className="flex gap-3">
            <button type="submit" className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
              Save
            </button>
            <button type="button" onClick={() => setShowForm(false)} className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium">
              Cancel
            </button>
          </div>
        </form>
      )}

      {staff.length === 0 ? (
        <div className="receipt-card text-center py-10">
          <p className="text-ink/60">No staff yet. Add your first cashier or supervisor.</p>
        </div>
      ) : (
        <div className="receipt-card overflow-hidden !p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-grey-light text-left">
                <th className="label-eyebrow px-5 py-3 font-medium">Name</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Role</th>
                <th className="label-eyebrow px-5 py-3 font-medium">PIN</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Status</th>
                <th className="px-5 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {staff.map((s) => (
                <tr key={s.id} className="border-b border-grey-light last:border-0">
                  <td className="px-5 py-3 font-medium">{s.name}</td>
                  <td className="px-5 py-3">
                    <span className={`text-xs font-medium px-2.5 py-1 rounded-full ${s.role === 'supervisor' ? 'bg-navy-50 text-navy' : 'bg-grey-light text-ink/60'}`}>
                      {s.role === 'supervisor' ? 'Supervisor' : 'Cashier'}
                    </span>
                  </td>
                  <td className="px-5 py-3 figure text-xs text-ink/40">••••</td>
                  <td className="px-5 py-3 text-xs text-ink/50">{s.active ? 'Active' : 'Inactive'}</td>
                  <td className="px-5 py-3 text-right">
                    <button onClick={() => openEditForm(s)} className="text-navy text-xs font-medium mr-3">
                      Edit
                    </button>
                    <button onClick={() => handleDelete(s.id)} className="text-rust text-xs font-medium">
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
STAFFEOF

cat > src/app/dashboard/settings/page.tsx << 'SETEOF'
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { useI18n } from '@/lib/i18n';
import { hashPin } from '@/lib/hash';
import { planLabel, daysRemaining, type PlanInfo } from '@/lib/plan';

export default function SettingsPage() {
  const supabase = createClient();
  const { t, lang, setLang } = useI18n();
  const [businessId, setBusinessId] = useState<string | null>(null);
  const [planInfo, setPlanInfo] = useState<PlanInfo | null>(null);
  const [syncApiKey, setSyncApiKey] = useState<string>('');
  const [form, setForm] = useState({
    name: '',
    address: '',
    phone: '',
    footer_text: '',
    tax_percent: '0',
    service_percent: '0',
    discount_percent: '0',
    rounding_enabled: false,
    rounding_nearest: '100',
    manager_pin: '',
    pin_required_for_cancel: true,
    print_check_enabled: true,
    queue_number_enabled: false,
    queue_start_number: '1',
    points_redemption_value: '100',
    points_redemption_multiple: '300',
    points_earn_rate: '1000',
    logo_base64: '' as string | null,
  });
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;

      const { data: link } = await supabase.from('business_users').select('business_id').eq('user_id', user.id).single();
      if (!link) return;

      const { data: business } = await supabase.from('businesses').select('*').eq('id', link.business_id).single();
      if (business) {
        setBusinessId(business.id);
        setPlanInfo({ plan: business.plan, plan_expires_at: business.plan_expires_at });
        setSyncApiKey(business.sync_api_key ?? '');
        setForm({
          name: business.name ?? '',
          address: business.address ?? '',
          phone: business.phone ?? '',
          footer_text: business.footer_text ?? '',
          tax_percent: String(business.tax_percent ?? 0),
          service_percent: String(business.service_percent ?? 0),
          discount_percent: String(business.discount_percent ?? 0),
          rounding_enabled: business.rounding_enabled ?? false,
          rounding_nearest: String(business.rounding_nearest ?? 100),
          manager_pin: '',
          pin_required_for_cancel: business.pin_required_for_cancel ?? true,
          print_check_enabled: business.print_check_enabled ?? true,
          queue_number_enabled: business.queue_number_enabled ?? false,
          queue_start_number: String(business.queue_start_number ?? 1),
          points_redemption_value: String(business.points_redemption_value ?? 100),
          points_redemption_multiple: String(business.points_redemption_multiple ?? 300),
          points_earn_rate: String(business.points_earn_rate ?? 1000),
          logo_base64: business.logo_base64,
        });
      }
      setLoading(false);
    }
    load();
  }, [supabase]);

  async function handleRegenerateKey() {
    if (!businessId) return;
    if (!confirm('Generate a new API key? The old key will stop working — any Flutter app still using it will need to be updated.')) return;
    const newKey = crypto.randomUUID().replace(/-/g, '');
    await supabase.from('businesses').update({ sync_api_key: newKey }).eq('id', businessId);
    setSyncApiKey(newKey);
  }

  function handleLogoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      const base64 = result.split(',')[1];
      setForm((f) => ({ ...f, logo_base64: base64 }));
    };
    reader.readAsDataURL(file);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!businessId) return;
    const payload: Record<string, unknown> = {
      name: form.name,
      address: form.address,
      phone: form.phone,
      footer_text: form.footer_text,
      tax_percent: Number(form.tax_percent) || 0,
      service_percent: Number(form.service_percent) || 0,
      discount_percent: Number(form.discount_percent) || 0,
      rounding_enabled: form.rounding_enabled,
      rounding_nearest: Number(form.rounding_nearest) || 100,
      pin_required_for_cancel: form.pin_required_for_cancel,
      print_check_enabled: form.print_check_enabled,
      queue_number_enabled: form.queue_number_enabled,
      queue_start_number: Number(form.queue_start_number) || 1,
      points_redemption_value: Number(form.points_redemption_value) || 100,
      points_redemption_multiple: Number(form.points_redemption_multiple) || 300,
      points_earn_rate: Number(form.points_earn_rate) || 1000,
      logo_base64: form.logo_base64 || null,
    };
    if (form.manager_pin.trim()) {
      payload.manager_pin = await hashPin(form.manager_pin.trim());
    }
    await supabase.from('businesses').update(payload).eq('id', businessId);
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  }

  if (loading) return <p className="text-sm text-ink/50">{t('loading')}</p>;

  return (
    <div className="max-w-lg">
      <p className="label-eyebrow mb-2">{t('business_settings')}</p>
      <h1 className="text-2xl font-semibold mb-2">{t('settings')}</h1>
      <p className="text-sm text-ink/60 mb-8">
        {t('settings_intro')}
      </p>

      <div className="receipt-card mb-8 flex items-center justify-between">
        <div>
          <p className="label-eyebrow mb-1">Current Plan</p>
          <p className="text-lg font-semibold text-navy">{planLabel(planInfo)}</p>
          {planInfo?.plan_expires_at && (
            <p className="text-xs text-ink/50 mt-1">
              {planInfo.plan === 'trial' ? 'Trial ends' : 'Renews/expires'}{' '}
              {new Date(planInfo.plan_expires_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })}
              {' '}({daysRemaining(planInfo.plan_expires_at)} days left)
            </p>
          )}
        </div>
        <a href="/pricing" className="rounded-full border border-navy text-navy px-5 py-2.5 text-sm font-medium shrink-0">
          View Plans
        </a>
      </div>

      <form onSubmit={handleSave} className="receipt-card flex flex-col gap-4">
        <p className="label-eyebrow">{t('business_profile')}</p>

        <div className="flex items-center gap-4">
          <div className="w-20 h-20 rounded-lg bg-cream border border-grey flex items-center justify-center overflow-hidden shrink-0">
            {form.logo_base64 ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={`data:image/png;base64,${form.logo_base64}`} alt="Logo" className="w-full h-full object-contain" />
            ) : (
              <span className="text-xs text-ink/40 text-center px-1">No logo</span>
            )}
          </div>
          <div>
            <input type="file" accept="image/*" onChange={handleLogoChange} className="text-xs" />
            <p className="text-xs text-ink/50 mt-1">Shown at the top of every printed receipt.</p>
          </div>
        </div>

        <div>
          <label className="label-eyebrow block mb-1.5">{t('business_name')}</label>
          <input
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('address')}</label>
          <textarea
            value={form.address}
            onChange={(e) => setForm({ ...form, address: e.target.value })}
            rows={2}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none resize-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('phone_number')}</label>
          <input
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('receipt_footer')}</label>
          <input
            value={form.footer_text}
            onChange={(e) => setForm({ ...form, footer_text: e.target.value })}
            placeholder="Thank you!"
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
        </div>

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">{t('tax_service_discount')}</p>
        <div className="grid grid-cols-3 gap-3">
          <div>
            <label className="label-eyebrow block mb-1.5">Tax (%)</label>
            <input
              type="number"
              value={form.tax_percent}
              onChange={(e) => setForm({ ...form, tax_percent: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <div>
            <label className="label-eyebrow block mb-1.5">Service (%)</label>
            <input
              type="number"
              value={form.service_percent}
              onChange={(e) => setForm({ ...form, service_percent: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <div>
            <label className="label-eyebrow block mb-1.5">Discount (%)</label>
            <input
              type="number"
              value={form.discount_percent}
              onChange={(e) => setForm({ ...form, discount_percent: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
        </div>

        <label className="flex items-center gap-2 text-sm pt-2">
          <input
            type="checkbox"
            checked={form.rounding_enabled}
            onChange={(e) => setForm({ ...form, rounding_enabled: e.target.checked })}
          />
          Round total to nearest
        </label>
        {form.rounding_enabled && (
          <select
            value={form.rounding_nearest}
            onChange={(e) => setForm({ ...form, rounding_nearest: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          >
            <option value="100">Rp 100</option>
            <option value="500">Rp 500</option>
            <option value="1000">Rp 1,000</option>
          </select>
        )}

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">{t('security')}</p>
        <div>
          <label className="label-eyebrow block mb-1.5">{t('manager_pin')}</label>
          <input
            value={form.manager_pin}
            onChange={(e) => setForm({ ...form, manager_pin: e.target.value })}
            placeholder="Leave blank to keep the current PIN"
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <p className="text-xs text-ink/50 mt-1">
            PINs are stored as a one-way hash, not as plain text, so this field is always blank —
            type here only when you want to set a new PIN.
          </p>
        </div>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.pin_required_for_cancel}
            onChange={(e) => setForm({ ...form, pin_required_for_cancel: e.target.checked })}
          />
          {t('require_pin_cancel')}
        </label>

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">{t('receipt_queue')}</p>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.print_check_enabled}
            onChange={(e) => setForm({ ...form, print_check_enabled: e.target.checked })}
          />
          Show &quot;Print Check&quot; button in POS
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.queue_number_enabled}
            onChange={(e) => setForm({ ...form, queue_number_enabled: e.target.checked })}
          />
          Enable queue numbers on receipts
        </label>
        {form.queue_number_enabled && (
          <div>
            <label className="label-eyebrow block mb-1.5">Queue Start Number (daily)</label>
            <input
              type="number"
              value={form.queue_start_number}
              onChange={(e) => setForm({ ...form, queue_start_number: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
        )}

        <p className="label-eyebrow pt-2 border-t border-grey-light mt-2">Loyalty Points</p>
        <div>
          <label className="label-eyebrow block mb-1.5">Earn Rate (Rp spent per 1 point)</label>
          <input
            type="number"
            value={form.points_earn_rate}
            onChange={(e) => setForm({ ...form, points_earn_rate: e.target.value })}
            className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <p className="text-xs text-ink/50 mt-1">
            e.g. 1000 means every Rp 1,000 spent earns 1 point (a Rp 30,000 purchase earns 30 points).
          </p>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label-eyebrow block mb-1.5">Redemption Value (Rp per point)</label>
            <input
              type="number"
              value={form.points_redemption_value}
              onChange={(e) => setForm({ ...form, points_redemption_value: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <div>
            <label className="label-eyebrow block mb-1.5">Redeem in Multiples of</label>
            <input
              type="number"
              value={form.points_redemption_multiple}
              onChange={(e) => setForm({ ...form, points_redemption_multiple: e.target.value })}
              className="w-full rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
        </div>
        <p className="text-xs text-ink/50 -mt-2">
          e.g. value 100 + multiple 300 means members redeem 300 points at a time for Rp 30,000 (10 points = Rp 1,000).
        </p>

        <button type="submit" className="rounded-full bg-navy text-white py-3 font-medium mt-2">
          {t('save_changes')}
        </button>
        {saved && <p className="text-sage text-sm text-center">{t('saved')}</p>}
      </form>

      <div className="receipt-card mt-8">
        <p className="label-eyebrow mb-2">{t('dashboard_language')}</p>
        <div className="flex gap-2 mt-3">
          <button
            type="button"
            onClick={() => setLang('en')}
            className={`flex-1 rounded-full px-4 py-2.5 text-sm font-medium border transition-colors ${
              lang === 'en' ? 'bg-navy text-white border-navy' : 'border-grey text-navy'
            }`}
          >
            English
          </button>
          <button
            type="button"
            onClick={() => setLang('id')}
            className={`flex-1 rounded-full px-4 py-2.5 text-sm font-medium border transition-colors ${
              lang === 'id' ? 'bg-navy text-white border-navy' : 'border-grey text-navy'
            }`}
          >
            Bahasa Indonesia
          </button>
        </div>
      </div>

      <div className="receipt-card mt-8">
        <p className="label-eyebrow mb-2">{t('sync')}</p>
        <h2 className="text-lg font-semibold mb-2">{t('connect_cashier_app')}</h2>
        <p className="text-sm text-ink/60 mb-4">
          Paste this code into the Tapply POS (Flutter) app used by your cashiers, once per device,
          so it can pull settings and push transactions automatically.
        </p>
        <div className="flex items-center gap-2 mb-3">
          <code className="flex-1 figure text-sm bg-cream border border-grey rounded-lg px-4 py-2.5 break-all">
            {syncApiKey || 'Loading...'}
          </code>
          <button
            type="button"
            onClick={() => {
              navigator.clipboard.writeText(syncApiKey);
              alert('Code copied!');
            }}
            className="rounded-lg border border-navy text-navy px-4 py-2.5 text-sm font-medium shrink-0"
          >
            Copy
          </button>
        </div>
        <button type="button" onClick={handleRegenerateKey} className="text-rust text-sm font-medium">
          Generate new code
        </button>
      </div>
    </div>
  );
}
SETEOF

echo 'Selesai. Jalankan migration_016 di Supabase SQL Editor, lalu npm run dev'
