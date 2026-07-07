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

const CHART_NAVY = '#623609';
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
